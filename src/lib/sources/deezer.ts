import type { Song } from '../game/types.ts';
import { isDesktop } from '../platform.ts';
import { createDeezerClient } from './deezer-core.ts';

/** The fields we use from Deezer's track objects. */
export interface DzTrack {
	id: number;
	readable?: boolean;
	title: string;
	title_short?: string;
	isrc?: string;
	duration: number;
	preview?: string;
	artist: { name: string };
	contributors?: { name: string }[];
	album?: { title: string; cover_medium?: string; cover_big?: string };
}

interface DzPage<T> {
	data: T[];
	total?: number;
	next?: string;
}

export class DeezerError extends Error {
	constructor(
		message: string,
		readonly code: number
	) {
		super(message);
	}
}

/** Deezer's "no data" error: the thing doesn't exist (or isn't public). */
export const NOT_FOUND = 800;

/** The desktop app talks to Deezer directly through Tauri's HTTP plugin (no CORS there). */
let desktopClient: ReturnType<typeof createDeezerClient> | undefined;

async function desktop() {
	if (!desktopClient) {
		const { fetch: tauriFetch } = await import('@tauri-apps/plugin-http');
		desktopClient = createDeezerClient({
			get: (url) => tauriFetch(url, { connectTimeout: 10_000 }),
			getNoRedirect: (url) => tauriFetch(url, { maxRedirections: 0, connectTimeout: 10_000 })
		});
	}
	return desktopClient;
}

const UNREACHABLE = "Can't reach Deezer. Check your connection.";

type Body<T> = (T & { error?: { message?: string; code?: number } }) | null;

async function api<T>(path: string, params: Record<string, string | number> = {}, signal?: AbortSignal): Promise<T> {
	const qs = new URLSearchParams(Object.entries(params).map(([k, v]) => [k, String(v)]));
	let body: Body<T>;
	let status = 0;
	try {
		if (isDesktop()) {
			body = (await (await desktop()).get(path, qs)) as Body<T>;
		} else {
			const res = await fetch(`/api/deezer/${path}${qs.size ? `?${qs}` : ''}`, { signal });
			status = res.status;
			body = (await res.json().catch(() => null)) as Body<T>;
		}
	} catch (e) {
		if (signal?.aborted) throw e;
		throw new DeezerError(UNREACHABLE, 0);
	}
	signal?.throwIfAborted();
	if (!body) throw new DeezerError('Deezer sent something unreadable.', status);
	if (body.error) throw new DeezerError(body.error.message ?? 'Deezer refused the request.', body.error.code ?? status);
	return body;
}

export function hasPreview(t: DzTrack): boolean {
	return t.readable !== false && !!t.preview;
}

export function toSong(t: DzTrack): Song {
	const names = [t.artist.name, ...(t.contributors ?? []).map((c) => c.name)];
	const song: Song = {
		id: t.id,
		title: t.title,
		artist: t.artist.name,
		artists: [...new Set(names)],
		album: t.album?.title ?? '',
		cover: t.album?.cover_medium ?? '',
		duration: t.duration
	};
	if (t.isrc) song.isrc = t.isrc;
	return song;
}

/** Search Deezer's catalogue. Only songs with a preview come back. */
export async function search(q: string, limit = 10, signal?: AbortSignal): Promise<Song[]> {
	if (!q.trim()) return [];
	const page = await api<DzPage<DzTrack>>('search', { q: q.slice(0, 200), limit }, signal);
	return page.data.filter(hasPreview).map(toSong);
}

/** A track with a fresh preview link (they expire after about 15 minutes). */
export async function track(id: number, signal?: AbortSignal): Promise<{ song: Song; preview: string | null }> {
	const t = await api<DzTrack>(`track/${id}`, {}, signal);
	return { song: toSong(t), preview: hasPreview(t) ? t.preview! : null };
}

export async function trackByIsrc(isrc: string, signal?: AbortSignal): Promise<DzTrack | null> {
	try {
		return await api<DzTrack>(`track/isrc:${isrc}`, {}, signal);
	} catch (e) {
		if (e instanceof DeezerError && e.code === NOT_FOUND) return null;
		throw e;
	}
}

export interface DzCollection {
	name: string;
	songs: Song[];
	/** Tracks Deezer lists but can't preview here. */
	skipped: number;
}

async function allTracks(path: string, signal?: AbortSignal, onProgress?: (n: number) => void): Promise<DzTrack[]> {
	const tracks: DzTrack[] = [];
	for (let index = 0; index < 5000; index += 100) {
		const page = await api<DzPage<DzTrack>>(path, { index, limit: 100 }, signal);
		tracks.push(...page.data);
		onProgress?.(tracks.length);
		if (!page.next || page.data.length === 0) break;
	}
	return tracks;
}

function collect(name: string, tracks: DzTrack[]): DzCollection {
	const playable = tracks.filter(hasPreview);
	const seen = new Set<number>();
	const songs = playable.map(toSong).filter((s) => !seen.has(s.id) && seen.add(s.id));
	return { name, songs, skipped: tracks.length - playable.length };
}

export async function playlist(id: string, signal?: AbortSignal, onProgress?: (n: number) => void): Promise<DzCollection> {
	const info = await api<{ title: string }>(`playlist/${id}`, {}, signal);
	return collect(info.title, await allTracks(`playlist/${id}/tracks`, signal, onProgress));
}

export async function album(id: string, signal?: AbortSignal): Promise<DzCollection> {
	const info = await api<{ title: string; cover_medium?: string; artist?: { name: string } }>(`album/${id}`, {}, signal);
	const tracks = await allTracks(`album/${id}/tracks`, signal);
	// Album track lists leave out the album itself.
	for (const t of tracks) t.album ??= { title: info.title, cover_medium: info.cover_medium };
	return collect(info.title, tracks);
}

/** Follow a Deezer share link (link.deezer.com/s/…) to the page it points to. */
export async function resolveShortLink(url: string, signal?: AbortSignal): Promise<string> {
	if (isDesktop()) {
		const target = await (await desktop()).resolveShortLink(url).catch(() => null);
		if (!target) throw new DeezerError("That share link didn't lead to a playlist.", 404);
		return target;
	}
	const res = await fetch(`/api/resolve?url=${encodeURIComponent(url)}`, { signal });
	const body = (await res.json().catch(() => null)) as { url?: string; error?: string } | null;
	if (!body?.url) throw new DeezerError(body?.error ?? "That share link didn't lead to a playlist.", res.status);
	return body.url;
}
