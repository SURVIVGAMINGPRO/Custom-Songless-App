/** A song we can play: every song in the library is a Deezer track with a preview. */
export interface Song {
	/** Deezer track ID. */
	id: number;
	title: string;
	/** Main artist. */
	artist: string;
	/** Every known artist, main artist first. */
	artists: string[];
	album: string;
	/** Album cover URL, or '' when Deezer has none. */
	cover: string;
	/** Full song length in seconds. */
	duration: number;
	isrc?: string;
	/** Spotify track ID, when the song came from a Spotify export. */
	spotify?: string;
}

/** A row from an import (CSV, pasted text) before it is matched to Deezer. */
export interface ImportItem {
	title: string;
	artists: string[];
	album?: string;
	durationMs?: number;
	isrc?: string;
	spotify?: string;
}

/** An imported row we couldn't match with confidence; shown for review. */
export interface Unmatched extends ImportItem {
	reason: 'not_found' | 'unsure';
	candidates: Song[];
}

export interface Playlist {
	id: string;
	name: string;
	source: 'deezer' | 'spotify' | 'built';
	/** The link it was imported from, if any. */
	sourceUrl?: string;
	songIds: number[];
	unmatched: Unmatched[];
	createdAt: number;
	updatedAt: number;
}

export type GuessResult = 'correct' | 'artist' | 'wrong';

/** What a player picked from the search list. */
export interface GuessPick {
	id: number;
	title: string;
	artist: string;
	artists?: string[];
	isrc?: string;
}

export type Attempt = { kind: 'skip' } | { kind: 'guess'; pick: GuessPick; result: GuessResult };

export type Mode = 'unlimited' | 'daily';

export interface Round {
	songId: number;
	attempts: Attempt[];
	status: 'playing' | 'won' | 'lost';
	mode: Mode;
	/** Daily rounds: the day number (see `dayNumber`). */
	day?: number;
	startedAt: number;
	endedAt?: number;
}

/** A shuffled order of song IDs, dealt one by one so songs don't repeat. */
export interface Deck {
	order: number[];
	pos: number;
	/** Recently dealt IDs, kept out of the start of the next shuffle. */
	recent: number[];
}

export interface Stats {
	played: number;
	won: number;
	/** dist[i] = rounds won on attempt i + 1; the last slot counts losses. */
	dist: number[];
	streak: number;
	best: number;
	/** Daily stats: the last day played, to know whether the streak continues. */
	lastDay?: number;
}

export type GuessScope = 'catalog' | 'game';

export interface Game {
	id: string;
	name: string;
	playlistIds: string[];
	/** Clip length in seconds for each attempt. */
	steps: number[];
	/** Kept for older saves; guesses always come from the game's own songs now. */
	guessScope: GuessScope;
	/** Keyed by tab ('all' or a playlist ID). */
	decks: Record<string, Deck>;
	/** Current unlimited round, keyed by tab. */
	rounds: Record<string, Round>;
	/** Daily rounds, keyed `${tab}:${day}`. */
	daily: Record<string, Round>;
	/** Keyed `${mode}:${tab}`. */
	stats: Record<string, Stats>;
	createdAt: number;
	updatedAt: number;
}

export type Appearance = 'system' | 'light' | 'dark';

export interface Settings {
	/** 0 to 1. */
	volume: number;
	appearance: Appearance;
	mode: Mode;
	gameId?: string;
	seenHelp: boolean;
	/** Changed keyboard shortcuts by action (null = none); see src/lib/keys.ts. */
	keys?: Record<string, string | null>;
}

export interface Library {
	version: 1;
	songs: Record<number, Song>;
	playlists: Playlist[];
	games: Game[];
	settings: Settings;
}
