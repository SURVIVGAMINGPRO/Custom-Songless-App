import { fold, normalizeArtist, normalizeTitle } from './normalize.ts';
import type { Song } from './types.ts';

/**
 * Find songs in the game's own playlists as the player types. Every word typed
 * has to start a word of the title or artist; titles that start with the
 * query come first, then other title matches, then artist matches.
 */
export function searchSongs(songs: Iterable<Song>, query: string, limit = 8): Song[] {
	const words = fold(query).split(' ').filter(Boolean);
	if (words.length === 0) return [];
	const q = words.join(' ');

	const hits: { song: Song; rank: number }[] = [];
	const seen = new Set<string>();
	for (const song of songs) {
		const title = fold(song.title);
		const artist = fold(song.artists.join(' '));
		const haystack = ` ${title} ${artist}`;
		if (!words.every((w) => haystack.includes(` ${w}`))) continue;

		const key = `${normalizeTitle(song.title)}|${normalizeArtist(song.artist)}`;
		if (seen.has(key)) continue;
		seen.add(key);

		let rank = 3;
		if (title.startsWith(q)) rank = 0;
		else if (` ${title}`.includes(` ${q}`)) rank = 1;
		else if (words.every((w) => ` ${title}`.includes(` ${w}`))) rank = 1.5;
		else if (` ${artist}`.includes(` ${q}`)) rank = 2;
		hits.push({ song, rank });
	}
	return hits
		.sort((a, b) => a.rank - b.rank || a.song.title.localeCompare(b.song.title))
		.slice(0, limit)
		.map((h) => h.song);
}
