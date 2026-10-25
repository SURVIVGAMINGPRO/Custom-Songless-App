/** The parts of an AudioBuffer we read, so tests can pass a plain object. */
export interface Samples {
	sampleRate: number;
	length: number;
	getChannelData(channel: number): Float32Array;
}

/**
 * Where the sound really starts, in seconds. Previews often open with silence
 * or a fade-in, which would make a 0.1 s clip useless, so skip ahead to the
 * first 10 ms that is at least 30% as loud as the clip overall (at most 4 s in).
 */
export function soundStart(buffer: Samples): number {
	const data = buffer.getChannelData(0);
	const rate = buffer.sampleRate;
	const win = Math.max(1, Math.round(rate * 0.01));

	const span = Math.min(data.length, rate * 10);
	let sum = 0;
	for (let i = 0; i < span; i++) sum += data[i] * data[i];
	const overall = Math.sqrt(sum / Math.max(1, span));
	const threshold = Math.max(0.01, overall * 0.3);

	const limit = Math.min(data.length, rate * 4);
	for (let i = 0; i + win <= limit; i += win) {
		let s = 0;
		for (let j = i; j < i + win; j++) s += data[j] * data[j];
		if (Math.sqrt(s / win) >= threshold) return Math.max(0, i / rate - 0.01);
	}
	return 0;
}
