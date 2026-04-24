import { json } from '@sveltejs/kit';
import { getAgentApiBaseUrl } from '$lib/server/agent';
import type { RequestHandler } from './$types';

type RequestPayload = {
	lang?: string;
	soulerId?: string;
	chapterId?: string;
};

function normalizeLang(lang: string | undefined) {
	return lang === 'en' ? 'en' : 'zh';
}

export const POST: RequestHandler = async ({ request, locals }) => {
	const { session } = await locals.safeGetSession();
	if (!session) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}

	const payload = (await request.json().catch(() => null)) as RequestPayload | null;
	if (!payload?.soulerId || !payload.chapterId) {
		return json({ error: 'Missing soulerId or chapterId' }, { status: 400 });
	}

	const lang = normalizeLang(payload.lang);
	let baseUrl: string;
	try {
		baseUrl = getAgentApiBaseUrl();
	} catch (err) {
		const message = err instanceof Error ? err.message : 'Missing agent base url';
		return json({ error: message }, { status: 500 });
	}
	const endpoint = `${baseUrl}/${lang}/soulers/${payload.soulerId}/chapters/${payload.chapterId}/start`;

	const upstream = await fetch(endpoint, {
		method: 'POST',
		headers: {
			authorization: `Bearer ${session.access_token}`,
			accept: 'application/json',
			'content-type': 'application/json'
		},
		body: '{}'
	});

	const text = await upstream.text();
	return new Response(text, {
		status: upstream.status,
		headers: {
			'content-type': upstream.headers.get('content-type') ?? 'application/json'
		}
	});
};
