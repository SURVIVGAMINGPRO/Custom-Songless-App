/**
 * The Deezer connection used by both the web server route and the desktop app:
 * only the paths the app needs, under Deezer's rate limit, with a short cache.
 * Each side passes its own fetch (Node's, or Tauri's HTTP plugin).
 */

const API = 'https://api.deezer.com/';

/** Paths the app may ask for. */
const PATHS = [
	/^search$/,
	/^track\/\d+$/,
	/^track\/isrc:[A-Z0-9]{12}$/i,
	/^playlist\/\d+$/,
	/^playlist\/\d+\/tracks$/,
	/^album\/\d+$/,
	/^album\/\d+\/tracks$/
];
const PARAMS = ['q', 'limit', 'index'];

export const SHORT_HOSTS = ['link.deezer.com', 'deezer.page.link', 'dzr.page.link'];

export function allowedPath(path: string): boolean {
	return PATHS.some((p) => p.test(path));
}

/** Deezer allows 50 requests per 5 seconds per address; stay a little under. */
const WINDOW_MS = 5000;
const MAX_IN_WINDOW = 45;

/** Track lookups hold preview links that expire after about 15 minutes. */
function ttl(path: string): number {
	if (path.startsWith('track/')) return 5 * 60_000;
	if (path === 'search') return 10 * 60_000;
	return 2 * 60_000;
}

const CACHE_MAX = 1000;
/** Deezer's "quota exceeded" error code. */
const QUOTA = 4;

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export interface DeezerTransport {
	/** GET a URL and return the response. */
	get(url: string): Promise<Response>;
	/** GET a URL without following redirects. */
	getNoRedirect(url: string): Promise<Response>;
}

export function createDeezerClient(transport: DeezerTransport) {
	const stamps: number[] = [];
	const cache = new Map<string, { at: number; body: unknown }>();

	async function slot(): Promise<void> {
		for (;;) {
			const now = Date.now();
			while (stamps.length && now - stamps[0] >= WINDOW_MS) stamps.shift();
			if (stamps.length < MAX_IN_WINDOW) {
				stamps.push(now);
				return;
			}
			await sleep(WINDOW_MS - (now - stamps[0]) + 5);
		}
	}

	/** GET an allowed Deezer API path. Deezer's own errors come back in the body (`{ error }`). */
	async function get(path: string, query: URLSearchParams): Promise<unknown> {
		if (!allowedPath(path)) return { error: { type: 'NotAllowed', message: 'Not available.', code: 404 } };
		const qs = new URLSearchParams();
		for (const k of PARAMS) {
			const v = query.get(k);
			if (v !== null) qs.set(k, v.slice(0, 200));
		}
		const key = `${path}?${qs}`;
		const hit = cache.get(key);
		if (hit && Date.now() - hit.at < ttl(path)) return hit.body;

		for (let attempt = 0; ; attempt++) {
			await slot();
			const res = await transport.get(`${API}${key}`);
			const body = (await res.json()) as { error?: { code?: number } };
			if (body.error?.code === QUOTA && attempt < 3) {
				await sleep(1500 * (attempt + 1));
				continue;
			}
			if (!body.error) {
				if (cache.size >= CACHE_MAX) cache.delete(cache.keys().next().value!);
				cache.set(key, { at: Date.now(), body });
			}
			return body;
		}
	}

	/** Follow a Deezer share link's redirects, staying on Deezer's own hosts. */
	async function resolveShortLink(input: string): Promise<string | null> {
		let url: URL;
		try {
			url = new URL(input);
		} catch {
			return null;
		}
		if (!SHORT_HOSTS.includes(url.hostname)) return null;
		for (let hop = 0; hop < 5; hop++) {
			const res = await transport.getNoRedirect(url.toString());
			const location = res.headers.get('location');
			if (!location) return null;
			url = new URL(location, url);
			const host = url.hostname.replace(/^www\./, '');
			if (host === 'deezer.com') return /\/(playlist|album)\/\d+/.test(url.pathname) ? url.toString() : null;
			if (!SHORT_HOSTS.includes(url.hostname)) return null;
		}
		return null;
	}

	return { get, resolveShortLink };
}
