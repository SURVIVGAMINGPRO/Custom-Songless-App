import { describe, expect, it } from 'vitest';
import { soundStart } from './silence.ts';

function buffer(seconds: number, loudFrom: number, rate = 1000) {
	const data = new Float32Array(seconds * rate);
	for (let i = Math.round(loudFrom * rate); i < data.length; i++) data[i] = Math.sin(i) * 0.5;
	return { sampleRate: rate, length: data.length, getChannelData: () => data };
}

describe('soundStart', () => {
	it('starts at 0 when the clip is loud from the start', () => {
		expect(soundStart(buffer(10, 0))).toBe(0);
	});
	it('skips leading silence', () => {
		expect(soundStart(buffer(10, 1.5))).toBeCloseTo(1.49, 2);
	});
	it('gives up after 4 seconds', () => {
		expect(soundStart(buffer(10, 6))).toBe(0);
	});
});
