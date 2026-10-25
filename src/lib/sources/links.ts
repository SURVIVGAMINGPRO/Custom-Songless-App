export type ParsedLink =
	| { kind: 'deezer-playlist'; id: string }
	| { kind: 'deezer-album'; id: string }
	| { kind: 'deezer-short'; url: string }
	| { kind: 'spotify-playlist'; id: string; url: string };

/** Hosts of Deezer's share links, which redirect to the real playlist URL. */
export const DEEZER_SHORT_HOSTS = ['link.deezer.com', 'deezer.page.link', 'dzr.page.link'];

/** Recognise a pasted playlist link. Returns null for anything else. */
export function parseLink(input: string): ParsedLink | null {
	const text = input.trim();

	const uri = text.match(/^spotify:playlist:([A-Za-z0-9]{22})$/);
	if (uri) return { kind: 'spotify-playlist', id: uri[1], url: `https://open.spotify.com/playlist/${uri[1]}` };

	let url: URL;
	try {
		url = new URL(/^https?:\/\//i.test(text) ? text : `https://${text}`);
	} catch {
		return null;
	}
	const host = url.hostname.replace(/^www\./, '');
	const path = url.pathname;

	if (host === 'open.spotify.com' || host === 'play.spotify.com') {
		const m = path.match(/^\/(?:intl-[a-z-]+\/)?(?:embed\/)?playlist\/([A-Za-z0-9]{22})/i);
		return m ? { kind: 'spotify-playlist', id: m[1], url: `https://open.spotify.com/playlist/${m[1]}` } : null;
	}
	if (host === 'deezer.com') {
		const m = path.match(/^\/(?:[a-z]{2}(?:-[a-z]{2})?\/)?(playlist|album)\/(\d+)/i);
		if (!m) return null;
		return m[1].toLowerCase() === 'playlist' ? { kind: 'deezer-playlist', id: m[2] } : { kind: 'deezer-album', id: m[2] };
	}
	if (DEEZER_SHORT_HOSTS.includes(host)) return { kind: 'deezer-short', url: url.toString() };
	return null;
}

export function spotifyTrackUrl(id: string): string {
	return `https://open.spotify.com/track/${id}`;
}

export function deezerTrackUrl(id: number): string {
	return `https://www.deezer.com/track/${id}`;
}
