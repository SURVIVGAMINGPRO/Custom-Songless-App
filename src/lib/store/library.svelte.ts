import { dailyPick, draw } from '../game/deck.ts';
import { DEFAULT_STEPS, emptyStats, newRound, recordRound } from '../game/engine.ts';
import type { Appearance, Game, GuessScope, Library, Mode, Playlist, Round, Song, Stats, Unmatched } from '../game/types.ts';
import { type ActionId, type Bindings, withDefaults } from '../keys.ts';
import { get, set } from './db.ts';

const KEY = 'library';
/** Daily rounds older than this many days are dropped. */
const KEEP_DAYS = 60;

export const ALL = 'all';

export interface Tab {
	key: string;
	label: string;
}

function emptyLibrary(): Library {
	return {
		version: 1,
		songs: {},
		playlists: [],
		games: [],
		settings: { volume: 0.8, appearance: 'system', mode: 'unlimited', seenHelp: false }
	};
}

/** A random ID. randomUUID needs a secure context, which a desktop web view may not count as. */
function id(): string {
	if (typeof crypto.randomUUID === 'function') return crypto.randomUUID();
	const b = crypto.getRandomValues(new Uint8Array(16));
	b[6] = (b[6] & 0x0f) | 0x40;
	b[8] = (b[8] & 0x3f) | 0x80;
	const h = [...b].map((x) => x.toString(16).padStart(2, '0')).join('');
	return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}

/** Accept a saved or restored library only if it has the right shape. */
function isLibrary(x: unknown): x is Library {
	const l = x as Library;
	return (
		!!l &&
		l.version === 1 &&
		typeof l.songs === 'object' &&
		Array.isArray(l.playlists) &&
		Array.isArray(l.games) &&
		typeof l.settings === 'object'
	);
}

class LibraryStore {
	data = $state<Library>(emptyLibrary());
	ready = $state(false);
	/** Set when saving to this browser failed (private window, storage full). */
	saveError = $state(false);
	#timer: ReturnType<typeof setTimeout> | undefined;

	async load(): Promise<void> {
		try {
			const saved = await get<Library>(KEY);
			if (isLibrary(saved)) this.data = { ...emptyLibrary(), ...saved, settings: { ...emptyLibrary().settings, ...saved.settings } };
		} catch {
			this.saveError = true;
		}
		this.ready = true;
		addEventListener('pagehide', () => this.flush());
	}

	save(): void {
		clearTimeout(this.#timer);
		this.#timer = setTimeout(() => this.flush(), 250);
	}

	flush(): void {
		clearTimeout(this.#timer);
		set(KEY, $state.snapshot(this.data)).then(
			() => (this.saveError = false),
			() => (this.saveError = true)
		);
	}

	// Songs and playlists

	song(songId: number): Song | undefined {
		return this.data.songs[songId];
	}

	playlist(playlistId: string): Playlist | undefined {
		return this.data.playlists.find((p) => p.id === playlistId);
	}

	/** The first songs of these playlists that exist, for artwork. */
	songsOf(playlistIds: string[], limit = 12): Song[] {
		const out: Song[] = [];
		for (const pid of playlistIds) {
			for (const sid of this.playlist(pid)?.songIds ?? []) {
				const s = this.data.songs[sid];
				if (s) out.push(s);
				if (out.length >= limit) return out;
			}
		}
		return out;
	}

	/** Games that mix two or more playlists. Single-playlist games stay behind the scenes. */
	get mixes(): Game[] {
		return this.data.games.filter((g) => g.playlistIds.length > 1);
	}

	addSongs(songs: Song[]): void {
		for (const s of songs) {
			const old = this.data.songs[s.id];
			this.data.songs[s.id] = { ...old, ...s, spotify: s.spotify ?? old?.spotify };
		}
	}

	createPlaylist(p: {
		name: string;
		source: Playlist['source'];
		sourceUrl?: string;
		songs?: Song[];
		unmatched?: Unmatched[];
	}): Playlist {
		const songs = p.songs ?? [];
		this.addSongs(songs);
		const now = Date.now();
		const playlist: Playlist = {
			id: id(),
			name: p.name.trim().slice(0, 60) || 'New playlist',
			source: p.source,
			sourceUrl: p.sourceUrl,
			songIds: [...new Set(songs.map((s) => s.id))],
			unmatched: p.unmatched ?? [],
			createdAt: now,
			updatedAt: now
		};
		this.data.playlists.push(playlist);
		this.save();
		return this.data.playlists[this.data.playlists.length - 1];
	}

	renamePlaylist(playlist: Playlist, name: string): void {
		const clean = name.trim().slice(0, 60);
		if (!clean || clean === playlist.name) return;
		playlist.name = clean;
		playlist.updatedAt = Date.now();
		this.save();
	}

	/** Add songs to a playlist. Returns how many were new to it. */
	addToPlaylist(playlist: Playlist, songs: Song[]): number {
		this.addSongs(songs);
		const have = new Set(playlist.songIds);
		const fresh = songs.filter((s) => !have.has(s.id) && have.add(s.id));
		playlist.songIds.push(...fresh.map((s) => s.id));
		playlist.updatedAt = Date.now();
		this.save();
		return fresh.length;
	}

	removeFromPlaylist(playlist: Playlist, songId: number): void {
		playlist.songIds = playlist.songIds.filter((x) => x !== songId);
		playlist.updatedAt = Date.now();
		this.#pruneSongs();
		this.save();
	}

	/** Settle an import row that needed a look: add the chosen song, or drop it. */
	resolveUnmatched(playlist: Playlist, index: number, song: Song | null): void {
		playlist.unmatched.splice(index, 1);
		if (song) this.addToPlaylist(playlist, [song]);
		else this.save();
	}

	addUnmatched(playlist: Playlist, entries: Unmatched[]): void {
		playlist.unmatched.push(...entries);
		this.save();
	}

	deletePlaylist(playlist: Playlist): void {
		this.data.playlists = this.data.playlists.filter((p) => p.id !== playlist.id);
		for (const g of this.data.games) g.playlistIds = g.playlistIds.filter((x) => x !== playlist.id);
		this.data.games = this.data.games.filter((g) => g.playlistIds.length > 0);
		this.#pruneSongs();
		this.save();
	}

	/** Forget songs no playlist uses, unless a current round still needs them. */
	#pruneSongs(): void {
		const used = new Set(this.data.playlists.flatMap((p) => p.songIds));
		for (const g of this.data.games) {
			for (const r of [...Object.values(g.rounds), ...Object.values(g.daily)]) used.add(r.songId);
		}
		for (const key of Object.keys(this.data.songs)) {
			if (!used.has(Number(key))) delete this.data.songs[Number(key)];
		}
	}

	// Games

	game(gameId: string): Game | undefined {
		return this.data.games.find((g) => g.id === gameId);
	}

	get currentGame(): Game | undefined {
		const games = this.data.games;
		return games.find((g) => g.id === this.data.settings.gameId) ?? games[0];
	}

	createGame(g: { name: string; playlistIds: string[]; steps?: number[]; guessScope?: GuessScope }): Game {
		const now = Date.now();
		const game: Game = {
			id: id(),
			name: g.name.trim().slice(0, 60) || 'New game',
			playlistIds: g.playlistIds,
			steps: g.steps ?? [...DEFAULT_STEPS],
			guessScope: g.guessScope ?? 'catalog',
			decks: {},
			rounds: {},
			daily: {},
			stats: {},
			createdAt: now,
			updatedAt: now
		};
		this.data.games.push(game);
		this.data.settings.gameId = game.id;
		this.save();
		return this.data.games[this.data.games.length - 1];
	}

	updateGame(game: Game, patch: Partial<Pick<Game, 'name' | 'playlistIds' | 'steps' | 'guessScope'>>): void {
		const changed = (a: unknown[] | undefined, b: unknown[]) => !!a && a.join() !== b.join();
		const restart = changed(patch.steps, game.steps) || changed(patch.playlistIds, game.playlistIds);
		Object.assign(game, patch, { updatedAt: Date.now() });
		// Rounds in progress used the old clip lengths or songs; start them again.
		if (restart) {
			for (const [key, r] of Object.entries(game.rounds)) if (r.status === 'playing') delete game.rounds[key];
		}
		this.save();
	}

	deleteGame(game: Game): void {
		this.data.games = this.data.games.filter((g) => g.id !== game.id);
		if (this.data.settings.gameId === game.id) this.data.settings.gameId = this.data.games[0]?.id;
		this.#pruneSongs();
		this.save();
	}

	selectGame(game: Game): void {
		this.data.settings.gameId = game.id;
		this.save();
	}

	/** The game that plays just this playlist, made if needed. */
	gameForPlaylist(playlist: Playlist): Game {
		const existing = this.data.games.find((g) => g.playlistIds.length === 1 && g.playlistIds[0] === playlist.id);
		if (existing) {
			this.selectGame(existing);
			return existing;
		}
		return this.createGame({ name: playlist.name, playlistIds: [playlist.id] });
	}

	/** "All" plus one tab per playlist, like Songless's All / Rock / Hip Hop. */
	tabs(game: Game): Tab[] {
		const lists = game.playlistIds.map((pid) => this.playlist(pid)).filter((p): p is Playlist => !!p);
		if (lists.length === 1) return [{ key: ALL, label: lists[0].name }];
		return [{ key: ALL, label: 'All' }, ...lists.map((p) => ({ key: p.id, label: p.name }))];
	}

	/** Song IDs a tab plays. */
	pool(game: Game, tab: string): number[] {
		const ids = tab === ALL ? game.playlistIds : game.playlistIds.filter((pid) => pid === tab);
		const pool = new Set<number>();
		for (const pid of ids) for (const sid of this.playlist(pid)?.songIds ?? []) if (this.data.songs[sid]) pool.add(sid);
		return [...pool];
	}

	// Rounds

	round(game: Game, tab: string, mode: Mode, day: number): Round | undefined {
		return mode === 'daily' ? game.daily[`${tab}:${day}`] : game.rounds[tab];
	}

	/** Start the next round. `exclude` leaves out a song that couldn't be played. */
	startRound(game: Game, tab: string, mode: Mode, day: number, exclude: number[] = []): Round | null {
		const pool = this.pool(game, tab).filter((x) => !exclude.includes(x));
		if (pool.length === 0) return null;
		if (mode === 'daily') {
			const round = newRound(dailyPick(pool, day), 'daily', day);
			game.daily[`${tab}:${day}`] = round;
			for (const key of Object.keys(game.daily)) {
				if (Number(key.split(':').pop()) < day - KEEP_DAYS) delete game.daily[key];
			}
		} else {
			const next = draw(game.decks[tab], pool, Math.random);
			game.decks[tab] = next.deck;
			game.rounds[tab] = newRound(next.id, 'unlimited');
		}
		this.save();
		return this.round(game, tab, mode, day)!;
	}

	/** Store a round after a guess or skip; finished rounds go into the stats. */
	putRound(game: Game, tab: string, round: Round): void {
		if (round.mode === 'daily') game.daily[`${tab}:${round.day}`] = round;
		else game.rounds[tab] = round;
		if (round.status !== 'playing') {
			const key = `${round.mode}:${tab}`;
			game.stats[key] = recordRound(game.stats[key] ?? emptyStats(game.steps), round, game.steps);
		}
		this.save();
	}

	stats(game: Game, mode: Mode, tab: string): Stats {
		return game.stats[`${mode}:${tab}`] ?? emptyStats(game.steps);
	}

	// Settings and backups

	setVolume(v: number): void {
		this.data.settings.volume = v;
		this.save();
	}

	setAppearance(appearance: Appearance): void {
		this.data.settings.appearance = appearance;
		this.save();
	}

	/** Keyboard shortcuts: the player's changes over the defaults. */
	get keys(): Bindings {
		return withDefaults(this.data.settings.keys);
	}

	setKey(id: ActionId, combo: string | null): void {
		this.data.settings.keys = { ...this.data.settings.keys, [id]: combo };
		this.save();
	}

	resetKeys(): void {
		delete this.data.settings.keys;
		this.save();
	}

	setMode(mode: Mode): void {
		this.data.settings.mode = mode;
		this.save();
	}

	markHelpSeen(): void {
		this.data.settings.seenHelp = true;
		this.save();
	}

	backup(): string {
		return JSON.stringify({ app: 'custom-songless', ...$state.snapshot(this.data) }, null, 1);
	}

	/** Replace everything with a backup. Returns false if the file isn't one. */
	restore(text: string): boolean {
		let parsed: unknown;
		try {
			parsed = JSON.parse(text);
		} catch {
			return false;
		}
		if (!isLibrary(parsed)) return false;
		const { version, songs, playlists, games, settings } = parsed;
		this.data = { version, songs, playlists, games, settings: { ...emptyLibrary().settings, ...settings } };
		this.flush();
		return true;
	}

	reset(): void {
		this.data = emptyLibrary();
		this.flush();
	}
}

export const library = new LibraryStore();
