import { deezer } from '#lib/server/deezer.ts';
import { allowedPath } from '#lib/sources/deezer-core.ts';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ params, url }) => {
	if (!allowedPath(params.path)) {
		return Response.json({ error: { type: 'NotAllowed', message: 'Not available.', code: 404 } }, { status: 404 });
	}
	try {
		const body = await deezer.get(params.path, url.searchParams);
		return Response.json(body, { headers: { 'cache-control': 'no-store' } });
	} catch {
		return Response.json(
			{ error: { type: 'Unreachable', message: "Can't reach Deezer right now.", code: 0 } },
			{ status: 502 }
		);
	}
};
