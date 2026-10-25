/**
 * Server side of the Deezer connection for the web version: Deezer's API
 * answers without CORS headers, so the browser asks us and we ask Deezer.
 */
import { createDeezerClient } from '../sources/deezer-core.ts';

export const deezer = createDeezerClient({
	get: (url) => fetch(url, { signal: AbortSignal.timeout(10_000) }),
	getNoRedirect: (url) => fetch(url, { redirect: 'manual', signal: AbortSignal.timeout(10_000) })
});
