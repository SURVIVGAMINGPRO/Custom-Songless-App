/** Lowercase, strip accents and turn every run of non-letters/digits into one space. */
export function fold(s: string): string {
	return s
		.normalize('NFKD')
		.replace(/\p{M}+/gu, '')
		.toLowerCase()
		.replace(/&/g, ' and ')
		.replace(/[^\p{L}\p{N}]+/gu, ' ')
		.trim();
}

/**
 * The part of a title that names the song, so different releases compare equal:
 * "Come Together - Remastered 2009", "Come Together (Remastered 2009)" and
 * "Come Together (feat. X)" all become "come together".
 */
export function normalizeTitle(title: string): string {
	let t = title.replace(/\s+[-–—]\s+.*$/, '');
	t = t.replace(/[([{][^)\]}]*[)\]}]/g, ' ');
	t = t.replace(/\s(feat|ft|featuring)\.?\s.*$/i, '');
	const folded = fold(t);
	return folded || fold(title);
}

/** "The Beatles" and "Beatles" are the same artist. */
export function normalizeArtist(name: string): string {
	return fold(name).replace(/^the /, '');
}

/** Split a credit like "A feat. B & C" into its artists. */
export function splitArtists(credit: string): string[] {
	return credit
		.split(/\s*(?:,|;|\/|&|\bx\b|\band\b|\bfeat\.?|\bft\.?|\bfeaturing\b|\bwith\b|\bvs\.?)\s*/i)
		.map(normalizeArtist)
		.filter((a) => a.length > 0);
}

/** True when the two credits share an artist. */
export function artistsOverlap(a: string[], b: string[]): boolean {
	const fullA = new Set(a.map(normalizeArtist));
	if (b.some((x) => fullA.has(normalizeArtist(x)))) return true;
	const partsA = new Set(a.flatMap(splitArtists).filter((x) => x.length > 2));
	return b.flatMap(splitArtists).some((x) => x.length > 2 && partsA.has(x));
}

/** Share of words in `a` that also appear in `b` (0 to 1). */
export function wordOverlap(a: string, b: string): number {
	const wa = a.split(' ').filter(Boolean);
	if (wa.length === 0) return 0;
	const wb = new Set(b.split(' '));
	return wa.filter((w) => wb.has(w)).length / wa.length;
}
