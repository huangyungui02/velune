import { json } from '@sveltejs/kit';
import { getAgentApiBaseUrl } from '$lib/server/agent';
import { clearBookshelfCache } from '$lib/server/bookshelf-cache';
import type { RequestHandler } from './$types';

type StreamRequestPayload = {
	sessionId?: string;
	soulerId?: string;
	soulerName?: string;
	replyLength?: string;
	content?: string;
};

function normalizeLang(lang: string | null) {
	return lang === 'en' ? 'en' : 'zh';
}

function normalizeReplyLength(replyLength: string | undefined) {
	return replyLength === 'concise' ? 'concise' : 'standard';
}

export const POST: RequestHandler = async ({ request, url, locals }) => {
	const { session, user } = await locals.safeGetSession();
	if (!session || !user) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}

	const body = (await request.json().catch(() => null)) as StreamRequestPayload | null;
	const soulerId = body?.soulerId?.trim();
	const soulerName = body?.soulerName?.trim();
	const content = body?.content?.trim();

	if (!soulerId || !soulerName || !content) {
		return json({ error: 'Missing soulerId, soulerName, or content' }, { status: 400 });
	}

	const payload = {
		sessionId: body?.sessionId?.trim() || undefined,
		soulerId,
		soulerName,
		replyLength: normalizeReplyLength(body?.replyLength),
		content
	};

	const lang = normalizeLang(url.searchParams.get('lang'));
	let baseUrl: string;
	try {
		baseUrl = getAgentApiBaseUrl();
	} catch (err) {
		const message = err instanceof Error ? err.message : 'Missing agent base url';
		return json({ error: message }, { status: 500 });
	}

	const endpoint = `${baseUrl}/api/v1/${lang}/chat`;
	const upstream = await fetch(endpoint, {
		method: 'POST',
		headers: {
			authorization: `Bearer ${session.access_token}`,
			accept: 'text/event-stream',
			'content-type': 'application/json'
		},
		body: JSON.stringify(payload)
	});

	const contentType = upstream.headers.get('content-type') ?? '';
	if (!upstream.body) {
		return json({ error: 'Agent stream is empty' }, { status: 502 });
	}

	clearBookshelfCache(user.id);
	return new Response(upstream.body, {
		status: upstream.status,
		headers: {
			'content-type': contentType || 'text/event-stream',
			'cache-control': 'no-cache'
		}
	});
};
