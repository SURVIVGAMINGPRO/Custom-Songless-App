import { track } from '../sources/deezer.ts';
import { soundStart } from './silence.ts';

interface Loaded {
	buffer: AudioBuffer;
	/** Seconds of silence to skip at the start. */
	start: number;
}

/** How long a decoded preview stays in memory. */
const KEEP_MS = 10 * 60_000;
const KEEP_COUNT = 6;
/** Fade in and out so short clips don't click. */
const FADE = 0.005;

/**
 * Plays exact slices of a song's Deezer preview with the Web Audio API, so a
 * 0.13 s clip is 0.13 s. Previews are fetched fresh (their links expire) and
 * kept in memory only.
 */
export class ClipPlayer {
	playing = $state(false);
	loading = $state(false);
	/** Seconds played of the current clip. */
	position = $state(0);
	/** Length of the current clip in seconds. */
	length = $state(0);
	error = $state<string | null>(null);

	#ctx: AudioContext | null = null;
	#master: GainNode | null = null;
	#volume = 0.8;
	#cache = new Map<number, { at: number; loaded: Promise<Loaded> }>();
	#source: AudioBufferSourceNode | null = null;
	#raf = 0;
	#token = 0;

	get volume(): number {
		return this.#volume;
	}

	set volume(v: number) {
		this.#volume = Math.min(1, Math.max(0, v));
		if (this.#master) this.#master.gain.value = this.#volume;
	}

	#context(): AudioContext {
		if (!this.#ctx) {
			this.#ctx = new AudioContext();
			this.#master = this.#ctx.createGain();
			this.#master.gain.value = this.#volume;
			this.#master.connect(this.#ctx.destination);
		}
		return this.#ctx;
	}

	/** Fetch and decode a song's preview. Safe to call ahead of time. */
	load(id: number): Promise<Loaded> {
		const hit = this.#cache.get(id);
		if (hit && Date.now() - hit.at < KEEP_MS) return hit.loaded;

		const loaded = (async () => {
			const { preview } = await track(id);
			if (!preview) throw new Error('This song has no preview right now.');
			const res = await fetch(preview);
			if (!res.ok) throw new Error("Couldn't load this song's preview.");
			// Decode offline so loading ahead of time doesn't need a click first.
			const buffer = await new OfflineAudioContext(2, 1, 44_100).decodeAudioData(await res.arrayBuffer());
			return { buffer, start: soundStart(buffer) };
		})();
		this.#cache.set(id, { at: Date.now(), loaded });
		loaded.catch(() => this.#cache.delete(id));
		while (this.#cache.size > KEEP_COUNT) this.#cache.delete(this.#cache.keys().next().value!);
		return loaded;
	}

	preload(id: number): void {
		this.load(id).catch(() => {});
	}

	/** Play the first `seconds` of the song (after any silence). */
	async play(id: number, seconds: number): Promise<void> {
		const token = ++this.#token;
		this.#halt();
		this.error = null;
		const ctx = this.#context();
		// Resume inside the click, before anything is awaited.
		const resumed = ctx.state === 'suspended' ? ctx.resume() : Promise.resolve();

		let loaded: Loaded;
		this.loading = true;
		try {
			[loaded] = await Promise.all([this.load(id), resumed]);
		} catch (e) {
			if (token === this.#token) {
				this.loading = false;
				this.error = e instanceof Error ? e.message : "Couldn't play this song.";
			}
			return;
		}
		if (token !== this.#token) return;
		this.loading = false;

		const length = Math.max(FADE * 2, Math.min(seconds, loaded.buffer.duration - loaded.start));
		const src = ctx.createBufferSource();
		src.buffer = loaded.buffer;
		const env = ctx.createGain();
		const t0 = ctx.currentTime + 0.02;
		env.gain.setValueAtTime(0, t0);
		env.gain.linearRampToValueAtTime(1, t0 + FADE);
		env.gain.setValueAtTime(1, t0 + length - FADE);
		env.gain.linearRampToValueAtTime(0, t0 + length);
		src.connect(env).connect(this.#master!);
		src.start(t0, loaded.start, length);
		src.onended = () => {
			if (this.#source !== src) return;
			this.#source = null;
			cancelAnimationFrame(this.#raf);
			this.playing = false;
			this.position = 0;
		};

		this.#source = src;
		this.length = length;
		this.position = 0;
		this.playing = true;
		const tick = () => {
			this.position = Math.min(length, Math.max(0, ctx.currentTime - t0));
			if (this.#source === src) this.#raf = requestAnimationFrame(tick);
		};
		tick();
	}

	stop(): void {
		this.#token++;
		this.loading = false;
		this.#halt();
	}

	#halt(): void {
		cancelAnimationFrame(this.#raf);
		const src = this.#source;
		this.#source = null;
		if (src) {
			try {
				src.stop();
			} catch {
				// Already stopped.
			}
			src.disconnect();
		}
		this.playing = false;
		this.position = 0;
	}
}

export const player = new ClipPlayer();
