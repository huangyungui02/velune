import { browser } from '$app/environment';
import type { AiReplyLength } from '$lib/types';

const storageKey = 'velune:ai-reply-length';
const defaultReplyLength: AiReplyLength = 'standard';

function normalizeReplyLength(value: unknown): AiReplyLength {
	return value === 'concise' ? 'concise' : defaultReplyLength;
}

function readStoredReplyLength() {
	if (!browser) {
		return defaultReplyLength;
	}

	return normalizeReplyLength(window.localStorage.getItem(storageKey));
}

class AiReplyPreference {
	replyLength = $state<AiReplyLength>(readStoredReplyLength());

	setReplyLength(value: AiReplyLength) {
		const next = normalizeReplyLength(value);
		this.replyLength = next;
		if (browser) {
			window.localStorage.setItem(storageKey, next);
		}
	}
}

export const aiReplyPreference = new AiReplyPreference();

export function getAiReplyLength() {
	return browser ? readStoredReplyLength() : aiReplyPreference.replyLength;
}
