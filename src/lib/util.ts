import type { Song } from './game/types.ts';

/** Only show cover art from Deezer's image servers (restored backups are untrusted). */
export function coverUrl(song: Song | undefined): string | null {
	const url = song?.cover;
	if (!url) return null;
	try {
		const u = new URL(url);
		return u.protocol === 'https:' && (u.hostname.endsWith('.dzcdn.net') || u.hostname === 'api.deezer.com') ? url : null;
	} catch {
		return null;
	}
}

export function validSpotifyId(id: string | undefined): id is string {
	return !!id && /^[A-Za-z0-9]{22}$/.test(id);
}

export function plural(n: number, one: string, many = `${one}s`): string {
	return `${n.toLocaleString()} ${n === 1 ? one : many}`;
}

/** "5 h 12 min" until the next local midnight. */
export function untilMidnight(now = new Date()): string {
	const next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
	const mins = Math.max(1, Math.ceil((next.getTime() - now.getTime()) / 60_000));
	const h = Math.floor(mins / 60);
	return h > 0 ? `${h} h ${mins % 60} min` : `${mins} min`;
}
