import { describe, expect, it } from 'vitest';
import { dailyPick, dayNumber, draw, newDeck, seeded, syncDeck } from './deck.ts';
import {
	DEFAULT_STEPS,
	clipSeconds,
	emojiGrid,
	emptyStats,
	formatSeconds,
	guess,
	judge,
	newRound,
	parseSteps,
	recordRound,
	shareText,
	skip,
	stepIndex
} from './engine.ts';
import { artistsOverlap, normalizeArtist, normalizeTitle, splitArtists } from './normalize.ts';
import type { GuessPick, Song } from './types.ts';

const answer: Song = {
	id: 116348128,
	title: 'Come Together (Remastered 2009)',
	artist: 'The Beatles',
	artists: ['The Beatles'],
	album: 'Abbey Road',
	cover: '',
	duration: 258,
	isrc: 'GBAYE0601690'
};
const pick = (p: Partial<GuessPick>): GuessPick => ({ id: 1, title: 'Something', artist: 'Nobody', ...p });

describe('normalize', () => {
	it('drops version notes from titles', () => {
		expect(normalizeTitle('Come Together - Remastered 2009')).toBe('come together');
		expect(normalizeTitle('Come Together (Remastered 2009)')).toBe('come together');
		expect(normalizeTitle('Señorita (feat. Someone)')).toBe('senorita');
		expect(normalizeTitle('Song feat. Other Person')).toBe('song');
		expect(normalizeTitle('Rock & Roll')).toBe('rock and roll');
	});
	it('keeps titles that are only brackets', () => {
		expect(normalizeTitle('(Intro)')).toBe('intro');
	});
	it('treats "The X" and "X" as one artist', () => {
		expect(normalizeArtist('The Beatles')).toBe(normalizeArtist('beatles'));
	});
	it('splits shared credits', () => {
		expect(splitArtists('Calvin Harris feat. Rihanna & Someone')).toEqual(['calvin harris', 'rihanna', 'someone']);
		expect(artistsOverlap(['Calvin Harris, Rihanna'], ['Rihanna'])).toBe(true);
		expect(artistsOverlap(['Simon & Garfunkel'], ['Simon & Garfunkel'])).toBe(true);
		expect(artistsOverlap(['Queen'], ['Queens of the Stone Age'])).toBe(false);
	});
});

describe('judge', () => {
	it('accepts the same track, the same ISRC, or the same song on another release', () => {
		expect(judge(pick({ id: answer.id }), answer)).toBe('correct');
		expect(judge(pick({ isrc: 'gbaye0601690' }), answer)).toBe('correct');
		expect(judge(pick({ title: 'Come Together - 2019 Mix', artist: 'Beatles' }), answer)).toBe('correct');
	});
	it('gives yellow for the right artist and red otherwise', () => {
		expect(judge(pick({ title: 'Something', artist: 'The Beatles' }), answer)).toBe('artist');
		expect(judge(pick({ title: 'Come Together', artist: 'Aerosmith' }), answer)).toBe('wrong');
	});
});

describe('round', () => {
	const steps = DEFAULT_STEPS;
	it('unlocks a longer clip after each miss or skip', () => {
		let r = newRound(answer.id, 'unlimited');
		expect(clipSeconds(r, steps)).toBe(0.13);
		r = skip(r, steps);
		expect(stepIndex(r, steps)).toBe(1);
		r = guess(r, pick({ artist: 'The Beatles' }), answer, steps);
		expect(clipSeconds(r, steps)).toBe(2);
		r = guess(r, pick({ id: answer.id }), answer, steps);
		expect(r.status).toBe('won');
		expect(emojiGrid(r, steps)).toBe('⬜🟧🟩⬛⬛');
		expect(clipSeconds(r, steps)).toBe(30);
	});
	it('ends after the last clip', () => {
		let r = newRound(answer.id, 'unlimited');
		for (let i = 0; i < steps.length; i++) r = skip(r, steps);
		expect(r.status).toBe('lost');
		expect(skip(r, steps)).toBe(r);
	});
	it('reads typed clip lengths', () => {
		expect(parseSteps('0.13, 0.53, 2, 8, 15')).toEqual(DEFAULT_STEPS);
		expect(parseSteps('1 2 4')).toEqual([1, 2, 4]);
		expect(parseSteps('2, 1')).toMatch(/longer/);
		expect(parseSteps('1, 40')).toMatch(/at most/);
		expect(parseSteps('1')).toMatch(/between/);
		expect(parseSteps('a, b')).toMatch(/numbers/);
	});
	it('formats clip lengths like Songless', () => {
		expect(formatSeconds(0.13)).toBe('0.1 seconds');
		expect(formatSeconds(0.53)).toBe('0.5 seconds');
		expect(formatSeconds(1)).toBe('1 second');
		expect(formatSeconds(15, true)).toBe('15s');
	});
	it('writes share text', () => {
		let r = newRound(answer.id, 'daily', 11);
		r = guess(r, pick({}), answer, steps);
		r = guess(r, pick({ id: answer.id }), answer, steps);
		expect(shareText({ app: 'Earshot', game: 'Road trip', tab: 'All', round: r, steps })).toBe(
			'Earshot #12 · Road trip · All\n🟥🟩⬛⬛⬛ 0.5s'
		);
	});
});

describe('stats', () => {
	const steps = DEFAULT_STEPS;
	const won = (day?: number) =>
		guess(newRound(1, day === undefined ? 'unlimited' : 'daily', day), pick({ id: answer.id }), answer, steps);
	it('counts wins, losses and streaks', () => {
		let s = emptyStats(steps);
		s = recordRound(s, won(), steps);
		s = recordRound(s, won(), steps);
		let lost = newRound(1, 'unlimited');
		for (let i = 0; i < steps.length; i++) lost = skip(lost, steps);
		s = recordRound(s, lost, steps);
		expect(s).toMatchObject({ played: 3, won: 2, streak: 0, best: 2, dist: [2, 0, 0, 0, 0, 1] });
	});
	it('breaks a daily streak when a day is missed', () => {
		let s = emptyStats(steps);
		s = recordRound(s, won(3), steps);
		s = recordRound(s, won(4), steps);
		expect(s.streak).toBe(2);
		s = recordRound(s, won(6), steps);
		expect(s.streak).toBe(1);
		expect(s.best).toBe(2);
	});
});

describe('deck', () => {
	const pool = Array.from({ length: 20 }, (_, i) => i + 1);
	it('deals every song once before repeating', () => {
		const rng = seeded(7);
		let deck;
		const seen: number[] = [];
		for (let i = 0; i < pool.length; i++) {
			const r = draw(deck, pool, rng);
			deck = r.deck;
			seen.push(r.id);
		}
		expect([...seen].sort((a, b) => a - b)).toEqual(pool);
	});
	it('keeps recent songs out of the start of the next shuffle', () => {
		const rng = seeded(3);
		let deck;
		const first: number[] = [];
		for (let i = 0; i < pool.length; i++) {
			const r = draw(deck, pool, rng);
			deck = r.deck;
			first.push(r.id);
		}
		const lastSix = first.slice(-6);
		const next = draw(deck, pool, rng);
		expect(lastSix).not.toContain(next.id);
	});
	it('follows songs being added and removed', () => {
		const rng = seeded(1);
		const deck = newDeck([1, 2, 3, 4], rng);
		const dealt = { ...deck, pos: 2 };
		const synced = syncDeck(dealt, [2, 3, 4, 5, 6], rng);
		expect(synced.order).toHaveLength(5);
		expect(synced.order).not.toContain(1);
		expect(new Set(synced.order)).toEqual(new Set([2, 3, 4, 5, 6]));
		// New songs only go into the part not dealt yet.
		expect(synced.order.slice(0, synced.pos)).not.toContain(5);
	});
});

describe('daily', () => {
	it('is the same for the same songs in any order, and cycles without repeats', () => {
		const pool = [30, 10, 20, 40, 50];
		expect(dailyPick(pool, 9)).toBe(dailyPick([...pool].reverse(), 9));
		const week = [0, 1, 2, 3, 4].map((d) => dailyPick(pool, d));
		expect(new Set(week).size).toBe(5);
	});
	it('counts days from 1 January 2026', () => {
		expect(dayNumber(new Date(2026, 0, 1, 23, 0))).toBe(0);
		expect(dayNumber(new Date(2026, 9, 25, 8, 0))).toBe(297);
	});
});
