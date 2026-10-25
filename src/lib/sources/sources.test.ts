import { describe, expect, it } from 'vitest';
import type { Song } from '../game/types.ts';
import { itemsFromCsv, itemsFromLines, parseCsv } from './csv.ts';
import { parseLink } from './links.ts';
import { MAYBE, SURE, rankCandidates, scoreCandidate, searchQuery } from './match.ts';

describe('parseLink', () => {
	it('reads Deezer playlist and album links', () => {
		expect(parseLink('https://www.deezer.com/en/playlist/3155776842')).toEqual({ kind: 'deezer-playlist', id: '3155776842' });
		expect(parseLink('deezer.com/playlist/123?utm_source=x')).toEqual({ kind: 'deezer-playlist', id: '123' });
		expect(parseLink('https://www.deezer.com/fr/album/302127')).toEqual({ kind: 'deezer-album', id: '302127' });
		expect(parseLink('https://link.deezer.com/s/30abcDEF')).toEqual({ kind: 'deezer-short', url: 'https://link.deezer.com/s/30abcDEF' });
	});
	it('reads Spotify playlist links and URIs', () => {
		const id = '37i9dQZF1DXcBWIGoYBM5M';
		const url = `https://open.spotify.com/playlist/${id}`;
		expect(parseLink(`${url}?si=abc`)).toEqual({ kind: 'spotify-playlist', id, url });
		expect(parseLink(`https://open.spotify.com/intl-de/playlist/${id}`)).toEqual({ kind: 'spotify-playlist', id, url });
		expect(parseLink(`spotify:playlist:${id}`)).toEqual({ kind: 'spotify-playlist', id, url });
	});
	it('ignores everything else', () => {
		expect(parseLink('https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC')).toBeNull();
		expect(parseLink('https://example.com/playlist/1')).toBeNull();
		expect(parseLink('not a link')).toBeNull();
	});
});

describe('csv', () => {
	it('handles quotes, commas and newlines inside fields', () => {
		expect(parseCsv('a,b\r\n"x, y","he said ""hi""\nthere"\n')).toEqual([
			['a', 'b'],
			['x, y', 'he said "hi"\nthere']
		]);
	});
	it('reads an Exportify export', () => {
		const csv = [
			'﻿"Track URI","Track Name","Artist URI(s)","Artist Name(s)","Album Name","Track Duration (ms)","ISRC"',
			'"spotify:track:2EqlS6tkEnglzr7tkKAAYD","Come Together - Remastered 2009","spotify:artist:3WrFJ7ztbogyGnTHbHJFl2","The Beatles","Abbey Road","259946","gbaye0601690"',
			'"spotify:track:0000000000000000000000","Under Pressure","x","Queen, David Bowie","Hot Space","248440",""'
		].join('\n');
		const r = itemsFromCsv(csv);
		expect(r.ok).toBe(true);
		if (!r.ok) return;
		expect(r.items).toEqual([
			{ title: 'Come Together - Remastered 2009', artists: ['The Beatles'], album: 'Abbey Road', durationMs: 259946, isrc: 'GBAYE0601690', spotify: '2EqlS6tkEnglzr7tkKAAYD' },
			{ title: 'Under Pressure', artists: ['Queen', 'David Bowie'], album: 'Hot Space', durationMs: 248440, spotify: '0000000000000000000000' }
		]);
	});
	it('reads simpler exports', () => {
		const r = itemsFromCsv('Title,Artist,ISRC\nHello,Adele,GBBKS1500214');
		expect(r).toEqual({ ok: true, items: [{ title: 'Hello', artists: ['Adele'], isrc: 'GBBKS1500214' }] });
	});
	it('explains files it cannot read', () => {
		expect(itemsFromCsv('Foo,Bar\n1,2')).toMatchObject({ ok: false });
		expect(itemsFromCsv('')).toMatchObject({ ok: false });
	});
	it('reads pasted lines', () => {
		expect(itemsFromLines('Queen - Bohemian Rhapsody\n\nHey Jude\n')).toEqual([
			{ artists: ['Queen'], title: 'Bohemian Rhapsody' },
			{ artists: [], title: 'Hey Jude' }
		]);
	});
});

describe('matching', () => {
	const song = (p: Partial<Song>): Song => ({ id: 1, title: 'x', artist: 'y', artists: ['y'], album: '', cover: '', duration: 200, ...p });
	const item = { title: 'Come Together - Remastered 2009', artists: ['The Beatles'], durationMs: 259946 };
	it('is sure about the same song by the same artist', () => {
		expect(scoreCandidate(item, song({ title: 'Come Together (Remastered 2009)', artists: ['The Beatles'], duration: 259 }))).toBeGreaterThanOrEqual(SURE);
	});
	it('is unsure about a longer title by the same artist', () => {
		const s = scoreCandidate(item, song({ title: 'Come Together / Something (Live)', artists: ['The Beatles'], duration: 400 }));
		expect(s).toBeGreaterThanOrEqual(MAYBE);
		expect(s).toBeLessThan(SURE);
	});
	it('rejects covers by other artists', () => {
		expect(scoreCandidate(item, song({ title: 'Come Together', artists: ['Aerosmith'], duration: 230 }))).toBeLessThan(SURE);
	});
	it('ranks the best result first', () => {
		const ranked = rankCandidates(item, [
			song({ id: 2, title: 'Come Together', artists: ['Aerosmith'] }),
			song({ id: 3, title: 'Come Together', artists: ['The Beatles'], duration: 260 })
		]);
		expect(ranked[0].song.id).toBe(3);
	});
	it('searches with the main artist and a clean title', () => {
		expect(searchQuery(item)).toBe('The Beatles Come Together');
		expect(searchQuery({ title: 'Hey Jude', artists: [] })).toBe('Hey Jude');
	});
});
