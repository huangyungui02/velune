import { json } from '@sveltejs/kit';
import { assertAdmin } from '$lib/server/admin';
import { getAgentApiBaseUrl } from '$lib/server/agent';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ locals, params }) => {
	const adminContext = await assertAdmin(locals);
	if (!adminContext) {
		return json({ error: 'Forbidden' }, { status: 403 });
	}

	const { session } = await locals.safeGetSession();
	const accessToken = session?.access_token;
	if (!accessToken) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}

	const response = await fetch(
		`${getAgentApiBaseUrl()}/v1/zh/soulers/resolutions/${encodeURIComponent(params.requestId)}`,
		{
			headers: {
				authorization: `Bearer ${accessToken}`
			}
		}
	);

	const payload = await response.json().catch(() => null);
	return json(payload ?? { error: 'Resolution status unavailable' }, { status: response.status });
};
