import { marked } from 'marked';
import type { ConversationMessage } from '$lib/types';

export type ParsedAssistantMessage = {
	content: string;
	options: string[];
};

export function normalizeOptions(raw: string[] | undefined) {
	if (!raw) {
		return [];
	}
	return raw
		.map((item) => item.trim())
		.filter(Boolean)
		.slice(0, 4);
}

export function parseAssistantMessage(rawContent: string): ParsedAssistantMessage {
	const jsonStartMarker = '---JSON---';
	const jsonEndMarker = '---END_JSON---';
	const startIndex = rawContent.lastIndexOf(jsonStartMarker);

	if (startIndex < 0) {
		return {
			content: rawContent.trim(),
			options: []
		};
	}

	const endIndex = rawContent.indexOf(jsonEndMarker, startIndex + jsonStartMarker.length);
	if (endIndex < 0) {
		return {
			content: rawContent.trim(),
			options: []
		};
	}

	const body = rawContent.slice(0, startIndex).trim();
	const jsonRaw = rawContent.slice(startIndex + jsonStartMarker.length, endIndex).trim();

	try {
		const parsed = JSON.parse(jsonRaw) as {
			options?: unknown;
		};
		const rawOptions = Array.isArray(parsed.options)
			? parsed.options.filter((item): item is string => typeof item === 'string')
			: undefined;

		return {
			content: body,
			options: normalizeOptions(rawOptions)
		};
	} catch {
		return {
			content: body,
			options: []
		};
	}
}

export function hydrateConversation(rawMessages: ConversationMessage[]) {
	const messages: ConversationMessage[] = [];
	const optionsByAssistantIndex: string[][] = [];

	for (const message of rawMessages) {
		if (message.role !== 'assistant') {
			messages.push(message);
			continue;
		}

		const parsed = parseAssistantMessage(message.content);
		messages.push({
			role: 'assistant',
			content: parsed.content
		});
		if (parsed.options.length > 0) {
			optionsByAssistantIndex[messages.length - 1] = parsed.options;
		}
	}

	let lastAssistantIndex = -1;
	for (let index = messages.length - 1; index >= 0; index -= 1) {
		if (messages[index].role === 'assistant') {
			lastAssistantIndex = index;
			break;
		}
	}

	return {
		messages,
		options: lastAssistantIndex >= 0 ? (optionsByAssistantIndex[lastAssistantIndex] ?? []) : []
	};
}

function escapeHtml(raw: string) {
	return raw
		.replaceAll('&', '&amp;')
		.replaceAll('<', '&lt;')
		.replaceAll('>', '&gt;')
		.replaceAll('"', '&quot;')
		.replaceAll("'", '&#39;');
}

function escapeAttribute(raw: string) {
	return raw
		.replaceAll('&', '&amp;')
		.replaceAll('"', '&quot;')
		.replaceAll('<', '&lt;')
		.replaceAll('>', '&gt;');
}

const markdownRenderer = new marked.Renderer();
markdownRenderer.html = () => '';
markdownRenderer.link = function ({ href, title, tokens }) {
	const parsed = this.parser.parseInline(tokens);
	if (!href) {
		return parsed;
	}
	const normalizedHref = href.trim();
	if (!/^(https?:|mailto:|\/|#)/i.test(normalizedHref)) {
		return parsed;
	}
	const safeHref = escapeAttribute(normalizedHref);
	const safeTitle = title ? ` title="${escapeAttribute(title)}"` : '';
	return `<a href="${safeHref}"${safeTitle} target="_blank" rel="noopener noreferrer nofollow">${parsed}</a>`;
};

export function renderAssistantMarkdown(raw: string) {
	const content = raw.trim();
	if (!content) {
		return '';
	}
	try {
		return marked.parse(escapeHtml(content), {
			async: false,
			gfm: true,
			breaks: true,
			renderer: markdownRenderer
		}) as string;
	} catch {
		return `<p>${escapeHtml(content)}</p>`;
	}
}
