import type { Deck } from './types.ts';

export type Rng = () => number;

/** Small seeded random number generator (mulberry32). */
export function seeded(seed: number): Rng {
	let a = seed >>> 0;
	return () => {
		a = (a + 0x6d2b79f5) >>> 0;
		let t = a;
		t = Math.imul(t ^ (t >>> 15), t | 1);
		t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}

/** FNV-1a hash of a string. */
export function hash(s: string): number {
	let h = 0x811c9dc5;
	for (let i = 0; i < s.length; i++) {
		h ^= s.charCodeAt(i);
		h = Math.imul(h, 0x01000193);
	}
	return h >>> 0;
}

export function shuffle<T>(items: T[], rng: Rng): T[] {
	const a = [...items];
	for (let i = a.length - 1; i > 0; i--) {
		const j = Math.floor(rng() * (i + 1));
		[a[i], a[j]] = [a[j], a[i]];
	}
	return a;
}

/** How many recently played songs are kept out of the start of a reshuffle. */
function recentLimit(size: number): number {
	return Math.min(50, Math.floor(size / 3));
}

/** A fresh shuffle; recently played songs go to the back so they don't come straight back. */
export function newDeck(pool: number[], rng: Rng, recent: number[] = []): Deck {
	const avoid = new Set(recent);
	const order = shuffle(pool, rng);
	return {
		order: [...order.filter((id) => !avoid.has(id)), ...order.filter((id) => avoid.has(id))],
		pos: 0,
		recent: recent.slice(-recentLimit(pool.length))
	};
}

/** Bring a deck in line with the pool: drop removed songs, slot new ones into the part not dealt yet. */
export function syncDeck(deck: Deck, pool: number[], rng: Rng): Deck {
	const inPool = new Set(pool);
	const dealt = deck.order.slice(0, deck.pos).filter((id) => inPool.has(id));
	const ahead = deck.order.slice(deck.pos).filter((id) => inPool.has(id));
	const known = new Set(deck.order);
	for (const id of pool) {
		if (known.has(id)) continue;
		ahead.splice(Math.floor(rng() * (ahead.length + 1)), 0, id);
	}
	return { order: [...dealt, ...ahead], pos: dealt.length, recent: deck.recent.filter((id) => inPool.has(id)) };
}

/** Deal the next song. Reshuffles when every song has been played once. */
export function draw(deck: Deck | undefined, pool: number[], rng: Rng): { deck: Deck; id: number } {
	if (pool.length === 0) throw new Error('No songs to play');
	let d = deck ? syncDeck(deck, pool, rng) : newDeck(pool, rng);
	if (d.pos >= d.order.length) d = newDeck(pool, rng, d.recent);
	const id = d.order[d.pos];
	const recent = [...d.recent.filter((r) => r !== id), id].slice(-recentLimit(pool.length));
	return { deck: { order: d.order, pos: d.pos + 1, recent }, id };
}

const DAY_ZERO = Date.UTC(2026, 0, 1);

/** Days since 1 January 2026 in the player's local time. */
export function dayNumber(date = new Date()): number {
	const local = Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());
	return Math.round((local - DAY_ZERO) / 86_400_000);
}

/**
 * The daily song: the same for everyone with the same songs, and no repeats
 * until every song has had its day.
 */
export function dailyPick(pool: number[], day: number): number {
	if (pool.length === 0) throw new Error('No songs to play');
	const sorted = [...new Set(pool)].sort((a, b) => a - b);
	const cycle = Math.floor(day / sorted.length);
	const order = shuffle(sorted, seeded(hash(sorted.join(',')) ^ cycle));
	return order[((day % sorted.length) + sorted.length) % sorted.length];
}
