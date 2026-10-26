import { describe, expect, it } from 'vitest';
import { searchSongs } from './search.ts';
import type { Song } from './types.ts';

let next = 1;
const song = (title: string, artist: string): Song => ({
	id: next++,
	title,
	artist,
	artists: [artist],
	album: '',
	cover: '',
	duration: 200
});

const songs = [
	song('Hey Jude', 'The Beatles'),
	song('Hello', 'Adele'),
	song('Hello (Live)', 'Adele'),
	song('Someone Like You', 'Adele'),
	song('Say Hello', 'Other Band'),
	song('Come Together', 'The Beatles'),
	song('Señorita', 'Shawn Mendes')
];

describe('searchSongs', () => {
	it('only finds songs from the given list', () => {
		expect(searchSongs(songs, 'bohemian')).toEqual([]);
		expect(searchSongs(songs, '')).toEqual([]);
	});

	it('puts titles that start with the query first, and leaves out repeats of a song', () => {
		expect(searchSongs(songs, 'hel').map((s) => s.title)).toEqual(['Hello', 'Say Hello']);
	});

	it('matches artists, and words in any order', () => {
		expect(searchSongs(songs, 'adele').map((s) => s.title)).toEqual(['Hello', 'Someone Like You']);
		expect(searchSongs(songs, 'beatles come').map((s) => s.title)).toEqual(['Come Together']);
	});

	it('matches the starts of words, ignoring accents and case', () => {
		expect(searchSongs(songs, 'senor').map((s) => s.title)).toEqual(['Señorita']);
		expect(searchSongs(songs, 'ude')).toEqual([]);
	});

	it('stops at the limit', () => {
		expect(searchSongs(songs, 'e', 2)).toHaveLength(0);
		expect(searchSongs(songs, 'the', 1)).toHaveLength(1);
	});
});
