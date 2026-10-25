import { fold } from '../game/normalize.ts';
import type { ImportItem } from '../game/types.ts';

/** RFC 4180 CSV: quoted fields, doubled quotes, commas and newlines inside quotes. */
export function parseCsv(text: string): string[][] {
	const rows: string[][] = [];
	let row: string[] = [];
	let field = '';
	let quoted = false;
	const src = text.replace(/^﻿/, '');
	for (let i = 0; i < src.length; i++) {
		const c = src[i];
		if (quoted) {
			if (c === '"') {
				if (src[i + 1] === '"') {
					field += '"';
					i++;
				} else quoted = false;
			} else field += c;
		} else if (c === '"') quoted = true;
		else if (c === ',') {
			row.push(field);
			field = '';
		} else if (c === '\n' || c === '\r') {
			if (c === '\r' && src[i + 1] === '\n') i++;
			row.push(field);
			rows.push(row);
			row = [];
			field = '';
		} else field += c;
	}
	if (field !== '' || row.length > 0) {
		row.push(field);
		rows.push(row);
	}
	return rows.filter((r) => r.some((f) => f.trim() !== ''));
}

/** Header names used by Exportify, TuneMyMusic, Soundiiz and similar tools. */
const COLUMNS = {
	title: ['track name', 'title', 'track', 'song', 'name', 'song name', 'track title'],
	artists: ['artist name s', 'artist names', 'artist name', 'artist', 'artists'],
	album: ['album name', 'album', 'album title'],
	duration: ['track duration ms', 'duration ms', 'duration'],
	isrc: ['isrc', 'track isrc'],
	uri: ['track uri', 'spotify uri', 'uri', 'spotify id', 'track id']
};

function findColumn(headers: string[], names: string[]): number {
	const folded = headers.map(fold);
	for (const name of names) {
		const i = folded.indexOf(name);
		if (i >= 0) return i;
	}
	return -1;
}

/** Artists in one cell: Exportify separates them with commas. */
function splitArtistCell(cell: string): string[] {
	return cell
		.split(/\s*[,;]\s*/)
		.map((a) => a.trim())
		.filter(Boolean);
}

function spotifyId(cell: string): string | undefined {
	return cell.match(/(?:spotify:track:|open\.spotify\.com\/track\/)?([A-Za-z0-9]{22})/)?.[1];
}

export type CsvResult = { ok: true; items: ImportItem[] } | { ok: false; error: string };

/** Turn an exported playlist CSV into import rows. */
export function itemsFromCsv(text: string): CsvResult {
	const rows = parseCsv(text);
	if (rows.length < 2) return { ok: false, error: 'This file has no songs in it.' };
	const [headers, ...body] = rows;
	const col = {
		title: findColumn(headers, COLUMNS.title),
		artists: findColumn(headers, COLUMNS.artists),
		album: findColumn(headers, COLUMNS.album),
		duration: findColumn(headers, COLUMNS.duration),
		isrc: findColumn(headers, COLUMNS.isrc),
		uri: findColumn(headers, COLUMNS.uri)
	};
	if (col.title < 0 || col.artists < 0) {
		return { ok: false, error: "This file doesn't have track name and artist columns. Export it again with Exportify." };
	}
	const items: ImportItem[] = [];
	for (const r of body) {
		const title = r[col.title]?.trim();
		const artists = splitArtistCell(r[col.artists] ?? '');
		if (!title || artists.length === 0) continue;
		const item: ImportItem = { title, artists };
		const album = col.album >= 0 ? r[col.album]?.trim() : '';
		if (album) item.album = album;
		const ms = col.duration >= 0 ? Number(r[col.duration]) : NaN;
		if (Number.isFinite(ms) && ms > 0) item.durationMs = ms > 10_000 ? ms : ms * 1000;
		const isrc = col.isrc >= 0 ? r[col.isrc]?.trim().toUpperCase() : '';
		if (isrc && /^[A-Z0-9]{12}$/.test(isrc)) item.isrc = isrc;
		const id = col.uri >= 0 ? spotifyId(r[col.uri] ?? '') : undefined;
		if (id) item.spotify = id;
		items.push(item);
	}
	if (items.length === 0) return { ok: false, error: 'No songs could be read from this file.' };
	return { ok: true, items };
}

/** Pasted lines like "Artist - Title" (or just a title) into import rows. */
export function itemsFromLines(text: string): ImportItem[] {
	return text
		.split(/\r?\n/)
		.map((line) => line.trim())
		.filter(Boolean)
		.map((line) => {
			const m = line.match(/^(.+?)\s+[-–—]\s+(.+)$/);
			return m ? { artists: [m[1].trim()], title: m[2].trim() } : { artists: [], title: line };
		});
}
