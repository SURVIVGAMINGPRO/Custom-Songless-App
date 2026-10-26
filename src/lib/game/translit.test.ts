import { beforeAll, describe, expect, it } from 'vitest';
import { normalizeArtist } from './normalize.ts';
import { prepareSearch, searchSongs } from './search.ts';
import { loadPinyin, toLatin } from './translit.ts';
import type { Song } from './types.ts';

let next = 1;
const song = (title: string, artist = 'Someone'): Song => ({
	id: next++,
	title,
	artist,
	artists: [artist],
	album: '',
	cover: '',
	duration: 200
});

/** Does typing `query` find a song called `title`? */
function finds(title: string, query: string, artist?: string): boolean {
	const s = song(title, artist);
	return searchSongs([s], query).length === 1;
}

describe('toLatin', () => {
	it('romanizes Cyrillic', () => {
		expect(toLatin('Банкомат')).toBe('bankomat');
		expect(toLatin('Жизнь')).toBe('zhizn');
		expect(toLatin('Щедрик')).toBe('shchedrik');
		expect(toLatin('Їжак')).toBe('yizhak');
	});
	it('romanizes Greek, Armenian and Georgian', () => {
		expect(toLatin('Αγάπη')).toBe('agapi');
		expect(toLatin('Σε θέλω')).toBe('se thelo');
		expect(toLatin('Սեր')).toBe('ser');
		expect(toLatin('სიყვარული')).toBe('siqvaruli');
	});
	it('romanizes Korean, Japanese kana and Thai', () => {
		expect(toLatin('사랑해')).toBe('saranghae');
		expect(toLatin('さくら')).toBe('sakura');
		expect(toLatin('カタオモイ')).toBe('kataomoi');
		expect(toLatin('がっこう')).toBe('gakkou');
		expect(toLatin('รัก')).toBe('rak');
	});
	it('romanizes Indic scripts, dropping the final inherent vowel', () => {
		expect(toLatin('दिल')).toBe('dil');
		expect(toLatin('तुम ही हो')).toBe('tum hi ho');
		expect(toLatin('गंगा')).toBe('ganga');
		expect(toLatin('காதல்')).toBe('katal');
	});
	it('leaves Latin text alone, apart from special letters', () => {
		expect(toLatin('Hello World')).toBe('hello world');
		expect(toLatin('Straße')).toBe('strasse');
		expect(toLatin('Øresund')).toBe('oresund');
	});
});

describe('searching other alphabets with Latin letters', () => {
	beforeAll(async () => {
		await loadPinyin();
	});

	it('finds Russian, Ukrainian and Serbian titles however they are spelled', () => {
		expect(finds('Банкомат', 'Bankomat')).toBe(true);
		expect(finds('Банкомат', 'bank')).toBe(true);
		expect(finds('Группа крови', 'gruppa krovi', 'Кино')).toBe(true);
		expect(finds('Группа крови', 'kino', 'Кино')).toBe(true);
		expect(finds('Звезда по имени Солнце', 'zvezda po imeni solntse')).toBe(true);
		expect(finds('Звезда по имени Солнце', 'solnce')).toBe(true);
		expect(finds('Песня', 'pesnya')).toBe(true);
		expect(finds('Песня', 'pesnja')).toBe(true);
		expect(finds('Песня', 'pesnia')).toBe(true);
		expect(finds('Хочешь', 'khochesh')).toBe(true);
		expect(finds('Хочешь', 'hochesh')).toBe(true);
		expect(finds('Щедрик', 'schedryk')).toBe(true);
		expect(finds('Ђорђе', 'djordje')).toBe(true);
		expect(finds('Ђорђе', 'đorđe')).toBe(true);
	});

	it('finds Greek, Armenian and Georgian titles', () => {
		expect(finds('Αγάπη μου', 'agapi mou')).toBe(true);
		expect(finds('Αγάπη μου', 'agapi mu')).toBe(true);
		expect(finds('Σε θέλω', 'se thelo')).toBe(true);
		expect(finds('Սեր', 'ser')).toBe(true);
		expect(finds('სიყვარული', 'siqvaruli')).toBe(true);
	});

	it('finds Hebrew and Arabic titles from their usual spellings', () => {
		expect(finds('שלום', 'shalom')).toBe(true);
		expect(finds('אהבה', 'ahava')).toBe(true);
		expect(finds('حبيبي', 'habibi')).toBe(true);
		expect(finds('نور', 'nour')).toBe(true);
		expect(finds('عشق', 'eshgh')).toBe(true);
	});

	it('finds Hindi, Tamil and Thai titles', () => {
		expect(finds('तुम ही हो', 'tum hi ho')).toBe(true);
		expect(finds('दिल', 'dil')).toBe(true);
		expect(finds('காதல்', 'kadhal')).toBe(true);
		expect(finds('காதல்', 'kaathal')).toBe(true);
		expect(finds('รัก', 'rak')).toBe(true);
	});

	it('finds Korean titles in Revised or older romanization', () => {
		expect(finds('사랑해', 'saranghae')).toBe(true);
		expect(finds('강남스타일', 'gangnam')).toBe(true);
		expect(finds('감사합니다', 'kamsahamnida')).toBe(true);
		expect(finds('서울', 'seoul')).toBe(true);
	});

	it('finds Japanese kana titles with or without long vowels', () => {
		expect(finds('ありがとう', 'arigatou')).toBe(true);
		expect(finds('ありがとう', 'arigato')).toBe(true);
		expect(finds('カタオモイ', 'kataomoi')).toBe(true);
	});

	it('finds Chinese titles by pinyin, joined or spaced', async () => {
		const songs = [song('晴天', '周杰伦'), song('月亮代表我的心', '邓丽君')];
		expect(await prepareSearch(songs)).toBe(true);
		expect(searchSongs(songs, 'qing tian')[0]?.title).toBe('晴天');
		expect(searchSongs(songs, 'qingtian')[0]?.title).toBe('晴天');
		expect(searchSongs(songs, 'zhou jie lun')[0]?.title).toBe('晴天');
		expect(searchSongs(songs, 'yueliang')[0]?.title).toBe('月亮代表我的心');
		expect(searchSongs(songs, 'yue liang daibiao')[0]?.title).toBe('月亮代表我的心');
		expect(searchSongs(songs, 'daibiao')[0]?.title).toBe('月亮代表我的心');
	});

	it('still matches the original alphabet and keeps Latin searches exact', () => {
		expect(finds('Банкомат', 'банкомат')).toBe(true);
		expect(finds('Hello', 'hel')).toBe(true);
		expect(finds('Hello', 'xyz')).toBe(false);
		expect(finds('Банкомат', 'zz')).toBe(false);
	});
});

describe('normalizeArtist still folds accents', () => {
	it('works', () => {
		expect(normalizeArtist('Beyoncé')).toBe('beyonce');
	});
});
