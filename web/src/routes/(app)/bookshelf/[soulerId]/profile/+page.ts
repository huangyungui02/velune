import { browser } from '$app/environment';
import { error } from '@sveltejs/kit';
import {
	readSoulerDetail,
	writeSoulerDetail
} from '$lib/stores/souler-detail-cache';
import type { PublicSoulerDetail } from '$lib/types';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ fetch, params }) => {
	if (browser) {
		const cached = readSoulerDetail(params.soulerId);
		if (cached) {
			return {
				souler: cached.souler,
				keywords: cached.keywords
			};
		}
	}

	const response = await fetch(`/api/soulers/${encodeURIComponent(params.soulerId)}/detail`);
	if (!response.ok) {
		error(response.status, '人物不存在');
	}

	const detail = (await response.json()) as PublicSoulerDetail;
	if (browser) {
		writeSoulerDetail(detail);
	}

	return {
		souler: detail.souler,
		keywords: detail.keywords
	};
};
