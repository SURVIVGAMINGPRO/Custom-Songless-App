import type { ImportItem, Song, Unmatched } from '../game/types.ts';
import { DeezerError, hasPreview, search, toSong, trackByIsrc } from './deezer.ts';
import { MAYBE, SURE, rankCandidates, searchQuery } from './match.ts';

export type MatchOutcome = { kind: 'matched'; song: Song } | { kind: 'unmatched'; entry: Unmatched };

/** Find an import row on Deezer: by ISRC first, then by searching title and artist. */
export async function matchItem(item: ImportItem, signal?: AbortSignal): Promise<MatchOutcome> {
	const withSpotify = (song: Song): Song => (item.spotify ? { ...song, spotify: item.spotify } : song);

	if (item.isrc) {
		const t = await trackByIsrc(item.isrc, signal);
		if (t && hasPreview(t)) return { kind: 'matched', song: withSpotify(toSong(t)) };
	}

	const results = await search(searchQuery(item), 10, signal);
	const ranked = rankCandidates(item, results);
	const best = ranked[0];
	if (best && best.score >= SURE) return { kind: 'matched', song: withSpotify(best.song) };

	const candidates = ranked.filter((r) => r.score >= MAYBE / 2).slice(0, 3).map((r) => withSpotify(r.song));
	const reason = best && best.score >= MAYBE ? 'unsure' : 'not_found';
	return { kind: 'unmatched', entry: { ...item, reason, candidates } };
}

export interface ImportProgress {
	done: number;
	total: number;
}

/**
 * Match many rows, a few at a time. The server keeps Deezer's rate limit, so
 * this only bounds how many requests wait at once.
 */
export async function matchAll(
	items: ImportItem[],
	opts: { signal?: AbortSignal; onProgress?: (p: ImportProgress) => void; concurrency?: number } = {}
): Promise<{ songs: Song[]; unmatched: Unmatched[] }> {
	const { signal, onProgress, concurrency = 4 } = opts;
	const outcomes: MatchOutcome[] = new Array(items.length);
	let next = 0;
	let done = 0;
	async function worker() {
		while (next < items.length) {
			signal?.throwIfAborted();
			const i = next++;
			try {
				outcomes[i] = await matchItem(items[i], signal);
			} catch (e) {
				// Give up on the whole import when Deezer can't be reached at all.
				if (signal?.aborted || (e instanceof DeezerError && e.code === 0)) throw e;
				outcomes[i] = { kind: 'unmatched', entry: { ...items[i], reason: 'not_found', candidates: [] } };
			}
			onProgress?.({ done: ++done, total: items.length });
		}
	}
	await Promise.all(Array.from({ length: Math.min(concurrency, items.length) }, worker));

	const seen = new Set<number>();
	const songs: Song[] = [];
	const unmatched: Unmatched[] = [];
	for (const o of outcomes) {
		if (o.kind === 'matched') {
			if (!seen.has(o.song.id)) {
				seen.add(o.song.id);
				songs.push(o.song);
			}
		} else unmatched.push(o.entry);
	}
	return { songs, unmatched };
}
