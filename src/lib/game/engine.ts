import { artistsOverlap, normalizeTitle } from './normalize.ts';
import type { Attempt, GuessPick, GuessResult, Mode, Round, Song, Stats } from './types.ts';

/** Clip lengths Songless uses, in seconds. Shown rounded to 0.1 s. */
export const DEFAULT_STEPS = [0.13, 0.53, 2, 8, 15];

/** Longest clip a step may ask for: Deezer previews are 30 s. */
export const MAX_STEP = 30;

/** Read clip lengths typed as "0.1, 0.5, 2, 8, 15". Returns an error message if they don't work. */
export function parseSteps(text: string): number[] | string {
	const parts = text.split(/[\s,;]+/).filter(Boolean);
	const steps = parts.map(Number);
	if (steps.some((s) => !Number.isFinite(s) || s <= 0)) return 'Use numbers of seconds, like 0.1, 0.5, 2, 8, 15.';
	if (steps.length < 2 || steps.length > 8) return 'Use between 2 and 8 clip lengths.';
	if (steps.some((s, i) => i > 0 && s <= steps[i - 1])) return 'Each clip has to be longer than the one before.';
	if (steps[steps.length - 1] > MAX_STEP) return `Clips can be at most ${MAX_STEP} seconds (the preview length).`;
	return steps;
}

export function newRound(songId: number, mode: Mode, day?: number): Round {
	return { songId, attempts: [], status: 'playing', mode, day, startedAt: Date.now() };
}

/** Index of the clip the player has unlocked. */
export function stepIndex(round: Round, steps: number[]): number {
	return Math.min(round.attempts.length, steps.length - 1);
}

/** How many seconds the play button plays right now. */
export function clipSeconds(round: Round, steps: number[]): number {
	return round.status === 'playing' ? steps[stepIndex(round, steps)] : MAX_STEP;
}

export function judge(pick: GuessPick, answer: Song): GuessResult {
	if (pick.id === answer.id) return 'correct';
	if (pick.isrc && answer.isrc && pick.isrc.toUpperCase() === answer.isrc.toUpperCase()) return 'correct';
	const sameArtist = artistsOverlap(pick.artists?.length ? pick.artists : [pick.artist], answer.artists);
	if (sameArtist && normalizeTitle(pick.title) === normalizeTitle(answer.title)) return 'correct';
	return sameArtist ? 'artist' : 'wrong';
}

function settle(round: Round, attempt: Attempt, steps: number[]): Round {
	const attempts = [...round.attempts, attempt];
	const won = attempt.kind === 'guess' && attempt.result === 'correct';
	const status = won ? 'won' : attempts.length >= steps.length ? 'lost' : 'playing';
	return { ...round, attempts, status, endedAt: status === 'playing' ? undefined : Date.now() };
}

export function guess(round: Round, pick: GuessPick, answer: Song, steps: number[]): Round {
	if (round.status !== 'playing') return round;
	return settle(round, { kind: 'guess', pick, result: judge(pick, answer) }, steps);
}

export function skip(round: Round, steps: number[]): Round {
	if (round.status !== 'playing') return round;
	return settle(round, { kind: 'skip' }, steps);
}

export function emptyStats(steps: number[]): Stats {
	return { played: 0, won: 0, dist: Array(steps.length + 1).fill(0), streak: 0, best: 0 };
}

/** Add a finished round to the stats. Daily streaks break when a day is missed. */
export function recordRound(stats: Stats, round: Round, steps: number[]): Stats {
	const dist = [...stats.dist];
	while (dist.length < steps.length + 1) dist.splice(dist.length - 1, 0, 0);
	const won = round.status === 'won';
	dist[won ? round.attempts.length - 1 : dist.length - 1]++;
	let streak = won ? stats.streak + 1 : 0;
	if (won && round.mode === 'daily' && round.day !== undefined && stats.lastDay !== undefined) {
		if (round.day !== stats.lastDay + 1) streak = 1;
	}
	return {
		played: stats.played + 1,
		won: stats.won + (won ? 1 : 0),
		dist,
		streak,
		best: Math.max(stats.best, streak),
		lastDay: round.mode === 'daily' ? round.day : stats.lastDay
	};
}

const EMOJI = { correct: '🟩', artist: '🟧', wrong: '🟥', skip: '⬜', empty: '⬛' };

export function emojiGrid(round: Round, steps: number[]): string {
	const cells = round.attempts.map((a) => (a.kind === 'skip' ? EMOJI.skip : EMOJI[a.result]));
	while (cells.length < steps.length) cells.push(EMOJI.empty);
	return cells.join('');
}

/** "0.1 seconds", "2 seconds": how Songless labels a clip. */
export function formatSeconds(s: number, short = false): string {
	const n = Number(s.toFixed(1));
	return short ? `${n}s` : `${n} ${n === 1 ? 'second' : 'seconds'}`;
}

export function shareText(opts: {
	app: string;
	game: string;
	tab?: string;
	round: Round;
	steps: number[];
}): string {
	const { app, game, tab, round, steps } = opts;
	const where = [game, tab].filter(Boolean).join(' · ');
	const title = round.mode === 'daily' && round.day !== undefined ? `${app} #${round.day + 1}` : app;
	const time =
		round.status === 'won' ? formatSeconds(steps[round.attempts.length - 1], true) : 'X';
	return `${title} · ${where}\n${emojiGrid(round, steps)} ${time}`;
}
