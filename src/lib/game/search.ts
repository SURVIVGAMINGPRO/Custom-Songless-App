import { fold, normalizeArtist, normalizeTitle } from './normalize.ts';
import { consonants, hasOtherScript, loadPinyin, loose, needsPinyin, toLatin, writesFewVowels } from './translit.ts';
import type { Song } from './types.ts';

/** One way of spelling a song for search: its title and artist as space-separated words. */
interface Spelling {
	title: string;
	artist: string;
}

interface SongKeys {
	/** As written (accents removed). */
	exact: Spelling;
	/** Romanized and loosened, for titles in other alphabets (one per reading of "ou"). */
	roman: Spelling[];
	/** Romanized consonants only, for Hebrew and Arabic titles. */
	bare?: Spelling;
}

const OU_READINGS = ['o', 'u'] as const;

function romanize(text: string, ou: 'o' | 'u'): string {
	return loose(fold(toLatin(text)), { ou });
}

const cache = new Map<string, SongKeys>();

function keysFor(song: Song): SongKeys {
	const artist = song.artists.join(' ');
	const id = `${song.id}|${song.title}|${artist}`;
	let keys = cache.get(id);
	if (keys) return keys;
	keys = { exact: { title: fold(song.title), artist: fold(artist) }, roman: [] };
	if (hasOtherScript(`${song.title} ${artist}`)) {
		keys.roman = OU_READINGS.map((ou) => ({ title: romanize(song.title, ou), artist: romanize(artist, ou) }));
		if (writesFewVowels(`${song.title} ${artist}`)) {
			const [r] = keys.roman;
			keys.bare = { title: consonants(r.title), artist: consonants(r.artist) };
		}
	}
	cache.set(id, keys);
	return keys;
}

/** Load what search needs for these songs (the pinyin reader, if any title is Chinese). */
export async function prepareSearch(songs: Iterable<Song>): Promise<boolean> {
	for (const s of songs) {
		if (needsPinyin(`${s.title} ${s.artists.join(' ')}`)) {
			await loadPinyin();
			cache.clear();
			return true;
		}
	}
	return false;
}

/** How well the typed words fit a spelling; null when they don't. Lower is better. */
function rankIn(words: string[], s: Spelling): number | null {
	if (words.length === 0) return null;
	const title = ` ${s.title}`;
	const haystack = ` ${s.title} ${s.artist}`;
	if (!words.every((w) => haystack.includes(` ${w}`))) return null;
	const q = words.join(' ');
	if (s.title.startsWith(q)) return 0;
	if (title.includes(` ${q}`)) return 1;
	if (words.every((w) => title.includes(` ${w}`))) return 1.5;
	if (` ${s.artist}`.includes(` ${q}`)) return 2;
	return 3;
}

/**
 * Find songs in the game's own playlists as the player types. Every word typed
 * has to start a word of the title or artist; titles that start with the
 * query come first, then other title matches, then artist matches. Titles in
 * other alphabets also match their romanized spelling ("bankomat" → "Банкомат").
 */
export function searchSongs(songs: Iterable<Song>, query: string, limit = 8): Song[] {
	const exact = fold(query).split(' ').filter(Boolean);
	if (exact.length === 0) return [];
	const romans = OU_READINGS.map((ou) => romanize(query, ou).split(' ').filter(Boolean));
	const bare = romans[0].map(consonants).filter(Boolean);

	const hits: { song: Song; rank: number }[] = [];
	const seen = new Set<string>();
	for (const song of songs) {
		const keys = keysFor(song);
		const ranks = [rankIn(exact, keys.exact)];
		for (const spelling of keys.roman) for (const words of romans) ranks.push(rankIn(words, spelling));
		// Consonants alone are a loose fit, so they rank after real matches.
		if (keys.bare && bare.length === romans[0].length) {
			const r = rankIn(bare, keys.bare);
			ranks.push(r === null ? null : r + 0.25);
		}
		const found = ranks.filter((r): r is number => r !== null);
		if (found.length === 0) continue;

		const key = `${normalizeTitle(song.title)}|${normalizeArtist(song.artist)}`;
		if (seen.has(key)) continue;
		seen.add(key);
		hits.push({ song, rank: Math.min(...found) });
	}
	return hits
		.sort((a, b) => a.rank - b.rank || a.song.title.localeCompare(b.song.title))
		.slice(0, limit)
		.map((h) => h.song);
}
