import { env } from '$env/dynamic/private';

export function getAgentApiBaseUrl() {
	const baseUrl = (env.AGENT_API_URL || env.PUBLIC_AGENT_API_URL || '').trim();
	if (!baseUrl) {
		throw new Error('Missing AGENT_API_URL (or PUBLIC_AGENT_API_URL) in environment variables.');
	}

	return baseUrl.replace(/\/+$/, '');
}
