import { snapdom } from '@zumer/snapdom';
import type { ConversationMessage } from '$lib/types';

type ShareChapter = {
	title: string;
	subtitle?: string | null;
};

type SharePayload = {
	chapter: ShareChapter;
	messages: ConversationMessage[];
};

type ImageSharePayload = {
	chapter: ShareChapter;
	source: HTMLElement;
};

export function hasShareableMessages(messages: ConversationMessage[]) {
	return messages.some((message) => message.content.trim());
}

export function buildConversationCopyText({ chapter, messages }: SharePayload) {
	const lines = [
		chapter.title,
		chapter.subtitle?.trim() ?? '',
		'--------',
		...messages.flatMap(formatCopyMessage)
	]
		.map((line) => line.trimEnd())
		.filter(Boolean);

	return lines.join('\n\n');
}

export async function copyConversationToClipboard(payload: SharePayload) {
	const text = buildConversationCopyText(payload);
	if (!text.trim()) {
		return;
	}

	try {
		await navigator.clipboard.writeText(text);
	} catch {
		copyTextFallback(text);
	}
}

export async function exportConversationImage({ chapter, source }: ImageSharePayload) {
	await document.fonts?.ready;
	await nextFrame();
	await nextFrame();

	const width = source.getBoundingClientRect().width;
	const previousWidth = source.style.width;
	const previousMinWidth = source.style.minWidth;
	const previousMaxWidth = source.style.maxWidth;
	const restoredBubbles = freezeUserBubbles(source);

	const resolvedSourceWidth = `${Math.ceil(width)}px`;
	source.style.width = resolvedSourceWidth;
	source.style.minWidth = resolvedSourceWidth;
	source.style.maxWidth = resolvedSourceWidth;

	try {
		await nextFrame();
		const blob = await snapdom.toBlob(source, {
			backgroundColor: '#fffdf8',
			cache: 'disabled',
			dpr: Math.min(window.devicePixelRatio || 2, 3),
			fast: false,
			type: 'png'
		});
		const url = URL.createObjectURL(blob);

		downloadUrl(url, exportFileName(chapter, 'png'));
		setTimeout(() => URL.revokeObjectURL(url));
	} finally {
		restoredBubbles();
		source.style.width = previousWidth;
		source.style.minWidth = previousMinWidth;
		source.style.maxWidth = previousMaxWidth;
	}
}

function formatCopyMessage(message: ConversationMessage) {
	const content = message.content.trim();
	if (!content) {
		return [];
	}

	if (message.role === 'user') {
		return ['--------', quoteUserContent(content), '--------'];
	}

	return [content];
}

function quoteUserContent(content: string) {
	return content
		.split('\n')
		.map((line) => `> ${line}`)
		.join('\n');
}

function exportFileName(chapter: ShareChapter, extension: string) {
	const date = new Date().toISOString().slice(0, 10);
	const name = `${chapter.title}-${date}`
		.replace(/[\\/:*?"<>|]/g, '-')
		.replace(/\s+/g, '-')
		.slice(0, 80);

	return `velune-${name}.${extension}`;
}

function downloadUrl(url: string, fileName: string) {
	const link = document.createElement('a');
	link.href = url;
	link.download = fileName;
	document.body.append(link);
	link.click();
	link.remove();
}

function freezeUserBubbles(source: HTMLElement) {
	const entries = Array.from(
		source.querySelectorAll<HTMLElement>('[data-conversation-user-message]')
	).map((bubble) => {
		const rect = bubble.getBoundingClientRect();
		const row = bubble.parentElement;
		const savedBubble = bubble.style.cssText;
		const savedRow = row?.style.cssText ?? '';

		if (row) {
			row.style.width = `${Math.ceil(row.getBoundingClientRect().width)}px`;
		}

		bubble.style.width = `${Math.ceil(rect.width) + 1}px`;
		bubble.style.minHeight = `${Math.ceil(rect.height)}px`;
		bubble.style.boxSizing = 'border-box';
		bubble.style.flex = 'none';
		bubble.style.overflowWrap = 'break-word';

		return () => {
			bubble.style.cssText = savedBubble;
			if (row) row.style.cssText = savedRow;
		};
	});

	return () => entries.forEach((r) => r());
}

function copyTextFallback(text: string) {
	const textarea = document.createElement('textarea');
	textarea.value = text;
	textarea.setAttribute('readonly', '');
	textarea.style.position = 'fixed';
	textarea.style.opacity = '0';
	document.body.append(textarea);
	textarea.select();
	document.execCommand('copy');
	textarea.remove();
}

function nextFrame() {
	return new Promise<void>((resolve) => requestAnimationFrame(() => resolve()));
}
