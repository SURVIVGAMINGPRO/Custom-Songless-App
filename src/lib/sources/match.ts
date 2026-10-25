import { artistsOverlap, fold, normalizeArtist, normalizeTitle, wordOverlap } from '../game/normalize.ts';
import type { ImportItem, Song } from '../game/types.ts';

/** Score at or above which a search result is taken without asking. */
export const SURE = 85;
/** Score at or above which a result is offered for review. */
export const MAYBE = 55;

/** How well a Deezer result fits an import row (roughly 0 to 100). */
export function scoreCandidate(item: ImportItem, c: Song): number {
	const t = normalizeTitle(item.title);
	const ct = normalizeTitle(c.title);
	let score: number;
	if (t === ct) score = 50;
	else if (ct.includes(t) || t.includes(ct)) score = 30;
	else score = 30 * wordOverlap(t, ct);

	if (item.artists.length === 0) score += 20;
	else {
		const credit = fold(item.artists.join(' '));
		if (artistsOverlap(item.artists, c.artists) || c.artists.some((a) => credit.includes(normalizeArtist(a))))
			score += 40;
	}

	if (item.durationMs && c.duration) {
		const diff = Math.abs(item.durationMs / 1000 - c.duration);
		if (diff <= 3) score += 10;
		else if (diff > 20) score -= 10;
	}
	return score;
}

export function rankCandidates(item: ImportItem, results: Song[]): { song: Song; score: number }[] {
	return results
		.map((song) => ({ song, score: scoreCandidate(item, song) }))
		.sort((a, b) => b.score - a.score);
}

/** The search text for an import row: main artist and the title without version notes. */
export function searchQuery(item: ImportItem): string {
	const title = item.title.replace(/\s+[-–—]\s+.*$/, '').replace(/\s*[([][^)\]]*[)\]]/g, '').trim() || item.title;
	return [item.artists[0] ?? '', title].join(' ').trim();
}
