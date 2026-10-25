import { describe, expect, it, vi } from 'vitest';
import { allowedPath, createDeezerClient } from './deezer-core.ts';

function json(body: unknown): Response {
	return new Response(JSON.stringify(body), { headers: { 'content-type': 'application/json' } });
}

describe('deezer-core', () => {
	it('allows only the paths the app uses', () => {
		expect(allowedPath('search')).toBe(true);
		expect(allowedPath('track/123')).toBe(true);
		expect(allowedPath('track/isrc:GBAYE0601690')).toBe(true);
		expect(allowedPath('playlist/1/tracks')).toBe(true);
		expect(allowedPath('user/1/flow')).toBe(false);
		expect(allowedPath('track/123/../../user')).toBe(false);
	});

	it('refuses other paths without calling Deezer', async () => {
		const get = vi.fn();
		const client = createDeezerClient({ get, getNoRedirect: get });
		expect(await client.get('user/1', new URLSearchParams())).toMatchObject({ error: { code: 404 } });
		expect(get).not.toHaveBeenCalled();
	});

	it('passes only known query parameters and caches answers', async () => {
		const get = vi.fn(async () => json({ data: [] }));
		const client = createDeezerClient({ get, getNoRedirect: get });
		const q = new URLSearchParams({ q: 'hello', limit: '5', access_token: 'x' });
		await client.get('search', q);
		await client.get('search', q);
		expect(get).toHaveBeenCalledTimes(1);
		expect(get).toHaveBeenCalledWith('https://api.deezer.com/search?q=hello&limit=5');
	});

	it('retries when Deezer says the quota is used up', async () => {
		vi.useFakeTimers();
		const get = vi
			.fn()
			.mockResolvedValueOnce(json({ error: { code: 4, message: 'Quota limit exceeded' } }))
			.mockResolvedValueOnce(json({ id: 1 }));
		const client = createDeezerClient({ get, getNoRedirect: get });
		const result = client.get('track/1', new URLSearchParams());
		await vi.runAllTimersAsync();
		expect(await result).toEqual({ id: 1 });
		expect(get).toHaveBeenCalledTimes(2);
		vi.useRealTimers();
	});

	it("doesn't cache Deezer's errors", async () => {
		const get = vi.fn(async () => json({ error: { code: 800, message: 'no data' } }));
		const client = createDeezerClient({ get, getNoRedirect: get });
		await client.get('track/2', new URLSearchParams());
		await client.get('track/2', new URLSearchParams());
		expect(get).toHaveBeenCalledTimes(2);
	});

	it('follows share links only to Deezer playlists and albums', async () => {
		const redirect = (to: string) => new Response(null, { status: 302, headers: { location: to } });
		const getNoRedirect = vi.fn(async (url: string) =>
			url.includes('/s/good')
				? redirect('https://www.deezer.com/en/playlist/123?utm=x')
				: url.includes('/s/away')
					? redirect('https://example.com/playlist/1')
					: redirect('https://www.deezer.com/deezer-links-404')
		);
		const client = createDeezerClient({ get: getNoRedirect, getNoRedirect });
		expect(await client.resolveShortLink('https://link.deezer.com/s/good')).toBe(
			'https://www.deezer.com/en/playlist/123?utm=x'
		);
		expect(await client.resolveShortLink('https://link.deezer.com/s/away')).toBeNull();
		expect(await client.resolveShortLink('https://link.deezer.com/s/gone')).toBeNull();
		expect(await client.resolveShortLink('https://example.com/s/good')).toBeNull();
	});
});
