import { deezer } from '#lib/server/deezer.ts';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ url }) => {
	const target = await deezer.resolveShortLink(url.searchParams.get('url') ?? '').catch(() => null);
	if (!target) return Response.json({ error: "That share link didn't lead to a Deezer playlist or album." }, { status: 404 });
	return Response.json({ url: target });
};
