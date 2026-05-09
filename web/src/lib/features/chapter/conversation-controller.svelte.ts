import {
	hydrateConversation,
	normalizeOptions,
	parseAssistantMessage
} from '$lib/features/chapter/assistant-content';
import { consumeAssistantStream, type AssistantEvent } from '$lib/features/chapter/stream-events';
import { getAiReplyLength } from '$lib/stores/ai-reply-preference.svelte';
import { requestBookshelfRefresh } from '$lib/stores/bookshelf-view-state';
import { touchSoulerChapterHistory } from '$lib/stores/souler-detail-cache';
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
	private messageSequence = 0;
	private activeRunId = 0;

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
		this.messages = hydrated.messages.map((message) =>
			this.createMessage(message.role, message.content)
		);
		this.options = hydrated.options;
	}

	private createMessage(role: ConversationMessage['role'], content: string): ConversationMessage {
		this.messageSequence += 1;
		return {
			id: `${role}-${Date.now().toString(36)}-${this.messageSequence}`,
			role,
			content
		};
	}

	private markMessagesChanged() {
		this.onMessagesChanged?.();
	}

	private touchChapterHistory() {
		if (!this.sessionId) {
			return;
		}

		touchSoulerChapterHistory(
			this.soulerId,
			this.chapterId,
			this.sessionId,
			this.messages.length
		);
		requestBookshelfRefresh();
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

		const runId = this.activeRunId + 1;
		this.activeRunId = runId;
		this.isLoading = true;
		this.errorMessage = '';
		this.options = [];
		this.messages = [this.createMessage('assistant', '')];
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
					chapterId: this.chapterId,
					replyLength: getAiReplyLength()
				})
			});

			const payload = (await response.json()) as StartPayload;
			if (runId !== this.activeRunId) {
				return;
			}
			if (!response.ok) {
				throw new Error(payload.error || '章节启动失败');
			}

			this.sessionId = payload.session_id;
			const parsedAssistant = parseAssistantMessage(payload.assistant_message.content);
			const normalizedOptions = normalizeOptions(payload.options);
			await this.streamAssistantContent(assistantIndex, parsedAssistant.content, runId);
			if (runId !== this.activeRunId) {
				return;
			}
			this.options = normalizedOptions.length > 0 ? normalizedOptions : parsedAssistant.options;
			this.touchChapterHistory();
		} catch (err) {
			if (!this.messages[assistantIndex]?.content.trim()) {
				this.messages = [];
				this.markMessagesChanged();
			}
			this.errorMessage = err instanceof Error ? err.message : '章节启动失败';
		} finally {
			if (runId === this.activeRunId) {
				this.isLoading = false;
			}
		}
	}

	async streamAssistantContent(assistantIndex: number, fullContent: string, runId: number) {
		const chunks = Array.from(fullContent);
		if (chunks.length === 0) {
			return;
		}

		for (let cursor = 0; cursor < chunks.length; ) {
			if (runId !== this.activeRunId) {
				return;
			}
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

		const runId = this.activeRunId + 1;
		this.activeRunId = runId;
		const previousOptions = this.options;
		this.inputValue = '';
		this.errorMessage = '';
		this.options = [];
		this.isLoading = true;

		this.messages.push(this.createMessage('user', content));
		this.messages.push(this.createMessage('assistant', ''));
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
					replyLength: getAiReplyLength(),
					content
				})
			});

			if (!response.ok || !response.body) {
				const fallback = await response.text();
				throw new Error(fallback || '消息发送失败');
			}

			await consumeAssistantStream(response.body, (event) => {
				if (runId !== this.activeRunId) {
					return;
				}
				this.handleAssistantEvent(event, assistantIndex);
			});
			if (runId !== this.activeRunId) {
				return;
			}
			this.touchChapterHistory();
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
			if (runId === this.activeRunId) {
				this.isLoading = false;
			}
		}
	}
}
