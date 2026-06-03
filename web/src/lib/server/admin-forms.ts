import {
	clampWeight,
	normalizeAdminTab,
	normalizeLang,
	normalizeNameKey,
	normalizeText,
	type AdminTab
} from '$lib/server/admin-common';

export type KeywordInput = {
	word: string;
	weight: number;
};

export type ParsedRows<T> =
	| {
			ok: true;
			rows: T[];
	  }
	| {
			ok: false;
			message: string;
	  };

export function parseKeywordRows(formData: FormData): ParsedRows<KeywordInput> {
	const words = formData.getAll('keyword_word').map((item) => String(item ?? '').trim());
	const weights = formData.getAll('keyword_weight').map((item) => String(item ?? '').trim());
	const unique = new Map<string, KeywordInput>();

	for (let index = 0; index < words.length; index += 1) {
		const word = words[index];
		if (!word) {
			continue;
		}

		const weightRaw = weights[index] ?? '';
		const weightNumber = weightRaw ? Number(weightRaw) : 0.5;
		if (!Number.isFinite(weightNumber)) {
			return {
				ok: false,
				message: `关键词「${word}」的 weight 无效。`
			};
		}

		unique.set(word.toLowerCase(), {
			word,
			weight: clampWeight(weightNumber)
		});
	}

	return {
		ok: true,
		rows: Array.from(unique.values()).slice(0, 30)
	};
}

export function parseSortOrder(raw: string) {
	const number = Number(raw);
	if (!Number.isFinite(number)) {
		return null;
	}
	return Math.floor(number);
}

export function parseCreateSoulerForm(formData: FormData) {
	return {
		name: normalizeText(formData.get('name')),
		lang: normalizeLang(formData.get('language'))
	};
}

export function parseSaveSoulerForm(formData: FormData) {
	const aliasText = normalizeText(formData.get('aliases'));
	const aliases = Array.from(
		new Map(
			aliasText
				.split(/[\n,]/)
				.map((item) => item.trim())
				.filter(Boolean)
				.map((alias) => [normalizeNameKey(alias), alias])
		).values()
	);

	return {
		soulerId: normalizeText(formData.get('souler_id')),
		name: normalizeText(formData.get('name')),
		introduction: normalizeText(formData.get('introduction')),
		lang: normalizeText(formData.get('lang')) || 'zh',
		wikidata: normalizeText(formData.get('wikidata')),
		checked: formData.get('checked') === 'on',
		aliases,
		tab: normalizeAdminTab(normalizeText(formData.get('tab')))
	};
}

export function parseSaveChaptersForm(formData: FormData) {
	return {
		soulerId: normalizeText(formData.get('souler_id')),
		lang: normalizeLang(formData.get('lang')),
		tab: normalizeAdminTab(normalizeText(formData.get('tab'))),
		chapterIds: formData
			.getAll('chapter_id')
			.map((item) => (typeof item === 'string' ? item.trim() : ''))
			.filter(Boolean),
		titles: formData.getAll('chapter_title').map((item) => String(item ?? '').trim()),
		subtitles: formData.getAll('chapter_subtitle').map((item) => String(item ?? '').trim()),
		tasks: formData.getAll('chapter_task').map((item) => String(item ?? '').trim())
	};
}

export function parseSoulerIdForm(formData: FormData): { soulerId: string; tab: AdminTab } {
	return {
		soulerId: normalizeText(formData.get('souler_id')),
		tab: normalizeAdminTab(normalizeText(formData.get('tab')))
	};
}

export function parseCreateSectionForm(formData: FormData) {
	const sortOrderRaw = normalizeText(formData.get('sort_order'));
	return {
		lang: normalizeLang(formData.get('lang')),
		title: normalizeText(formData.get('title')),
		subtitle: normalizeText(formData.get('subtitle')),
		sortOrderRaw,
		sortOrder: sortOrderRaw ? Number(sortOrderRaw) : 0
	};
}

export function parseSaveSectionForm(formData: FormData) {
	const sortOrderRaw = normalizeText(formData.get('sort_order'));
	return {
		sectionId: normalizeText(formData.get('section_id')),
		tab: normalizeAdminTab(normalizeText(formData.get('tab'))),
		lang: normalizeLang(formData.get('lang')),
		title: normalizeText(formData.get('title')),
		subtitle: normalizeText(formData.get('subtitle')),
		sortOrderRaw,
		sortOrder: parseSortOrder(sortOrderRaw || '0'),
		isActive: formData.get('is_active') === 'on'
	};
}

export function parseSectionItemForm(formData: FormData) {
	return {
		sectionId: normalizeText(formData.get('section_id')),
		soulerId: normalizeText(formData.get('souler_id')),
		tab: normalizeAdminTab(normalizeText(formData.get('tab')))
	};
}

export function parseSaveSectionItemsForm(formData: FormData) {
	return {
		sectionId: normalizeText(formData.get('section_id')),
		tab: normalizeAdminTab(normalizeText(formData.get('tab'))),
		soulerIds: formData
			.getAll('item_souler_id')
			.map((entry) => String(entry ?? '').trim())
			.filter(Boolean),
		sortOrders: formData.getAll('item_sort_order').map((entry) => String(entry ?? '').trim()),
		removedSoulerIds: new Set(
			formData
				.getAll('remove_souler_id')
				.map((entry) => String(entry ?? '').trim())
				.filter(Boolean)
		)
	};
}

export function parseSectionIdForm(formData: FormData) {
	return {
		sectionId: normalizeText(formData.get('section_id')),
		tab: normalizeAdminTab(normalizeText(formData.get('tab')))
	};
}
