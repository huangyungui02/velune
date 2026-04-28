import {
	hydrateConversation,
	normalizeOptions,
	parseAssistantMessage
} from '$lib/features/chapter/assistant-content';
import { consumeAssistantStream, type AssistantEvent } from '$lib/features/chapter/stream-events';
import type { ConversationMessage } from '$lib/types';

type StartPayload = {
	session_id: string;
	assistant_message: {
		content: string;
	};
	options?: string[];
	error?: string;
};

type ConversationControllerOptions = {
	soulerId: string;
	soulerName: string;
	chapterId: string;
	initialSessionId: string | null;
	initialMessages: ConversationMessage[];
	onMessagesChanged?: () => void;
};

export class ConversationController {
	private soulerId: string;
	private soulerName: string;
	private chapterId: string;
	private onMessagesChanged?: () => void;

	sessionId = $state<string | null>(null);
	inputValue = $state('');
	options = $state<string[]>([]);
	messages = $state<ConversationMessage[]>([]);
	isLoading = $state(false);
	errorMessage = $state('');

	constructor(options: ConversationControllerOptions) {
		this.soulerId = options.soulerId;
		this.soulerName = options.soulerName;
		this.chapterId = options.chapterId;
		this.onMessagesChanged = options.onMessagesChanged;
		this.sessionId = options.initialSessionId;
		const hydrated = hydrateConversation(options.initialMessages);
		this.messages = hydrated.messages;
		this.options = hydrated.options;
	}

	private markMessagesChanged() {
		this.onMessagesChanged?.();
	}

	private appendAssistantDelta(assistantIndex: number, delta: string) {
		if (!delta) {
			return;
		}
		this.messages[assistantIndex].content += delta;
		this.markMessagesChanged();
	}

	private handleAssistantEvent(event: AssistantEvent, assistantIndex: number) {
		switch (event.type) {
			case 'delta':
				this.appendAssistantDelta(assistantIndex, event.delta);
				break;
			case 'options':
				this.options = event.options;
				break;
			case 'done':
				if (event.sessionId) {
					this.sessionId = event.sessionId;
				}
				break;
			case 'error':
				throw new Error(event.message);
			default:
				break;
		}
	}

	async startChapter() {
		if (this.isLoading || this.sessionId) {
			return;
		}

		this.isLoading = true;
		this.errorMessage = '';
		this.options = [];
		this.messages = [{ role: 'assistant', content: '' }];
		this.markMessagesChanged();
		const assistantIndex = 0;

		try {
			const response = await fetch('/api/chapter/start', {
				method: 'POST',
				headers: {
					'content-type': 'application/json'
				},
				body: JSON.stringify({
					lang: 'zh',
					soulerId: this.soulerId,
					chapterId: this.chapterId
				})
			});

			const payload = (await response.json()) as StartPayload;
			if (!response.ok) {
				throw new Error(payload.error || '章节启动失败');
			}

			this.sessionId = payload.session_id;
			const parsedAssistant = parseAssistantMessage(payload.assistant_message.content);
			const normalizedOptions = normalizeOptions(payload.options);
			await this.streamAssistantContent(assistantIndex, parsedAssistant.content);
			this.options = normalizedOptions.length > 0 ? normalizedOptions : parsedAssistant.options;
		} catch (err) {
			if (!this.messages[assistantIndex]?.content.trim()) {
				this.messages = [];
				this.markMessagesChanged();
			}
			this.errorMessage = err instanceof Error ? err.message : '章节启动失败';
		} finally {
			this.isLoading = false;
		}
	}

	async streamAssistantContent(assistantIndex: number, fullContent: string) {
		const chunks = Array.from(fullContent);
		if (chunks.length === 0) {
			return;
		}

		for (let cursor = 0; cursor < chunks.length; ) {
			const remaining = chunks.length - cursor;
			const step = remaining > 420 ? 12 : remaining > 220 ? 8 : remaining > 90 ? 5 : 3;
			const nextCursor = Math.min(cursor + step, chunks.length);
			this.appendAssistantDelta(assistantIndex, chunks.slice(cursor, nextCursor).join(''));
			cursor = nextCursor;
			await new Promise((resolve) => setTimeout(resolve, 16));
		}
	}

	async sendMessage(optionText?: string) {
		const content = (optionText ?? this.inputValue).trim();
		if (!content || !this.sessionId || this.isLoading) {
			return;
		}

		const previousOptions = this.options;
		this.inputValue = '';
		this.errorMessage = '';
		this.options = [];
		this.isLoading = true;

		this.messages.push({ role: 'user', content });
		this.messages.push({ role: 'assistant', content: '' });
		this.markMessagesChanged();
		const assistantIndex = this.messages.length - 1;

		try {
			const response = await fetch('/api/chat/stream?lang=zh', {
				method: 'POST',
				headers: {
					'content-type': 'application/json'
				},
				body: JSON.stringify({
					sessionId: this.sessionId,
					soulerId: this.soulerId,
					soulerName: this.soulerName,
					content
				})
			});

			if (!response.ok || !response.body) {
				const fallback = await response.text();
				throw new Error(fallback || '消息发送失败');
			}

			await consumeAssistantStream(response.body, (event) => {
				this.handleAssistantEvent(event, assistantIndex);
			});
		} catch (err) {
			if (!this.messages[assistantIndex].content.trim()) {
				this.messages.pop();
				this.markMessagesChanged();
			}
			if (previousOptions.length > 0) {
				this.options = previousOptions;
			}
			this.errorMessage = err instanceof Error ? err.message : '消息发送失败';
		} finally {
			this.isLoading = false;
		}
	}
}
