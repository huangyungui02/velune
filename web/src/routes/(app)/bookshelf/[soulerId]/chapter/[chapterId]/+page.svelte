<script lang="ts">
	import { resolve } from '$app/paths';
	import { tick } from 'svelte';
	import UserRound from '@lucide/svelte/icons/user-round';
	import SendHorizontal from '@lucide/svelte/icons/send-horizontal';
	import { marked } from 'marked';
	import PageTopToolbar from '$lib/components/ui/page-top-toolbar.svelte';
	import { Button } from '$lib/components/ui/button/index.js';
	import { Input } from '$lib/components/ui/input/index.js';
	import type { ConversationMessage } from '$lib/types';
	import type { PageProps } from './$types';

	type StartPayload = {
		session_id: string;
		assistant_message: {
			content: string;
		};
		options?: string[];
	};

	type StreamPayload = {
		type: 'ready' | 'delta' | 'options' | 'done' | 'error';
		sessionId?: string;
		delta?: string;
		options?: string[];
		message?: string;
	};

	let { data }: PageProps = $props();

	let sessionId = $state<string | null>(null);
	let inputValue = $state('');
	let options = $state<string[]>([]);
	let messages = $state<ConversationMessage[]>([]);
	let isLoading = $state(false);
	let errorMessage = $state('');
	let messageContainer = $state<HTMLElement | null>(null);

	$effect(() => {
		sessionId = data.initialSessionId ?? null;
		const hydrated = hydrateConversation(data.initialMessages ?? []);
		messages = hydrated.messages;
		options = hydrated.options;
		inputValue = '';
		errorMessage = '';
		isLoading = false;
	});

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

	function renderAssistantMarkdown(raw: string) {
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

	$effect(() => {
		messages.length;
		tick().then(() => {
			if (messageContainer && messageContainer.lastElementChild) {
				messageContainer.lastElementChild.scrollIntoView({ behavior: 'smooth', block: 'start' });
			}
		});
	});

	function normalizeOptions(raw: string[] | undefined) {
		if (!raw) {
			return [];
		}
		return raw
			.map((item) => item.trim())
			.filter(Boolean)
			.slice(0, 4);
	}

	function parseAssistantMessage(rawContent: string) {
		const jsonStartMarker = '---JSON---';
		const jsonEndMarker = '---END_JSON---';
		const startIndex = rawContent.lastIndexOf(jsonStartMarker);

		if (startIndex < 0) {
			return {
				content: rawContent.trim(),
				options: [] as string[]
			};
		}

		const endIndex = rawContent.indexOf(jsonEndMarker, startIndex + jsonStartMarker.length);
		if (endIndex < 0) {
			return {
				content: rawContent.trim(),
				options: [] as string[]
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
				options: [] as string[]
			};
		}
	}

	function hydrateConversation(rawMessages: ConversationMessage[]) {
		const normalizedMessages: ConversationMessage[] = [];
		const optionsByAssistantIndex: string[][] = [];

		for (const message of rawMessages) {
			if (message.role !== 'assistant') {
				normalizedMessages.push(message);
				continue;
			}

			const parsed = parseAssistantMessage(message.content);
			normalizedMessages.push({
				role: 'assistant',
				content: parsed.content
			});
			if (parsed.options.length > 0) {
				optionsByAssistantIndex[normalizedMessages.length - 1] = parsed.options;
			}
		}

		let lastAssistantIndex = -1;
		for (let i = normalizedMessages.length - 1; i >= 0; i -= 1) {
			if (normalizedMessages[i].role === 'assistant') {
				lastAssistantIndex = i;
				break;
			}
		}

		return {
			messages: normalizedMessages,
			options:
				lastAssistantIndex >= 0
					? (optionsByAssistantIndex[lastAssistantIndex] ?? [])
					: ([] as string[])
		};
	}

	async function startChapter() {
		if (isLoading || sessionId) {
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			const response = await fetch('/api/chapter/start', {
				method: 'POST',
				headers: {
					'content-type': 'application/json'
				},
				body: JSON.stringify({
					lang: 'zh',
					soulerId: data.souler.id,
					chapterId: data.chapter.id
				})
			});

			const payload = (await response.json()) as StartPayload & { error?: string };
			if (!response.ok) {
				throw new Error(payload.error || '章节启动失败');
			}

			sessionId = payload.session_id;
			const parsedAssistant = parseAssistantMessage(payload.assistant_message.content);
			const normalizedOptions = normalizeOptions(payload.options);
			messages = [
				{
					role: 'assistant',
					content: parsedAssistant.content
				}
			];
			options = normalizedOptions.length > 0 ? normalizedOptions : parsedAssistant.options;
		} catch (err) {
			errorMessage = err instanceof Error ? err.message : '章节启动失败';
		} finally {
			isLoading = false;
		}
	}

	async function sendMessage(optionText?: string) {
		const content = (optionText ?? inputValue).trim();
		if (!content || !sessionId || isLoading) {
			return;
		}

		inputValue = '';
		errorMessage = '';
		isLoading = true;

		messages.push({ role: 'user', content });
		messages.push({ role: 'assistant', content: '' });
		const assistantIndex = messages.length - 1;

		try {
			const response = await fetch('/api/chat/stream?lang=zh', {
				method: 'POST',
				headers: {
					'content-type': 'application/json'
				},
				body: JSON.stringify({
					sessionId,
					soulerId: data.souler.id,
					soulerName: data.souler.name,
					content
				})
			});

			if (!response.ok || !response.body) {
				const fallback = await response.text();
				throw new Error(fallback || '消息发送失败');
			}

			options = [];
			await consumeStream(response.body, assistantIndex);
		} catch (err) {
			if (!messages[assistantIndex].content.trim()) {
				messages.pop();
			}
			errorMessage = err instanceof Error ? err.message : '消息发送失败';
		} finally {
			isLoading = false;
		}
	}

	async function consumeStream(stream: ReadableStream<Uint8Array>, assistantIndex: number) {
		const reader = stream.getReader();
		const decoder = new TextDecoder();
		let buffer = '';

		while (true) {
			const { value, done } = await reader.read();
			if (done) {
				break;
			}

			buffer += decoder.decode(value, { stream: true });
			const chunks = buffer.split('\n\n');
			buffer = chunks.pop() ?? '';

			for (const chunk of chunks) {
				handleEventChunk(chunk, assistantIndex);
			}
		}

		if (buffer.trim()) {
			handleEventChunk(buffer, assistantIndex);
		}
	}

	function handleEventChunk(chunk: string, assistantIndex: number) {
		const dataLines = chunk
			.split('\n')
			.filter((line) => line.startsWith('data:'))
			.map((line) => line.slice(5).trim())
			.filter(Boolean);

		if (dataLines.length === 0) {
			return;
		}

		let payload: StreamPayload;
		try {
			payload = JSON.parse(dataLines.join('\n')) as StreamPayload;
		} catch {
			return;
		}

		switch (payload.type) {
			case 'delta': {
				const delta = payload.delta ?? '';
				messages[assistantIndex].content += delta;
				break;
			}
			case 'options': {
				options = normalizeOptions(payload.options);
				break;
			}
			case 'done': {
				if (payload.sessionId) {
					sessionId = payload.sessionId;
				}
				break;
			}
			case 'error': {
				throw new Error(payload.message || '流式请求失败');
			}
			default:
				break;
		}
	}
</script>

<svelte:head>
	<title>Velune · {data.chapter.title}</title>
</svelte:head>

<div class="pb-36 pt-[calc(env(safe-area-inset-top)+3.4rem)] md:pb-32 md:pt-2">
	<PageTopToolbar title={data.chapter.title} backHref="/bookshelf" class="md:hidden">
		{#snippet children()}
			<Button
				href={resolve(`/bookshelf/${data.souler.id}`)}
				variant="ghost"
				size="icon-sm"
				class="size-9 rounded-full text-muted-foreground/80 hover:text-primary"
				aria-label="人物详情"
			>
				<UserRound class="size-4" />
			</Button>
		{/snippet}
	</PageTopToolbar>

	<header class="mb-6 hidden md:block">
		<h1 class="font-hand text-4xl leading-tight text-primary">{data.chapter.title}</h1>
		{#if data.chapter.subtitle}
			<p class="mt-2 text-sm leading-7 text-muted-foreground/80">{data.chapter.subtitle}</p>
		{/if}
	</header>

	<div class="px-2 md:px-4 space-y-6" bind:this={messageContainer}>
		{#if messages.length === 0}
			<p class="py-8 text-sm text-muted-foreground/60 text-center font-sans tracking-widest">
				—— 叙述由此展开 ——
			</p>
		{/if}

		{#each messages as message, index (`${message.role}-${index}`)}
			{#if message.role === 'assistant'}
				<article class="w-full px-1 text-[1.1rem] leading-8 text-foreground md:px-2">
					<div class="markdown-content">
						{@html renderAssistantMarkdown(
							message.content || (isLoading && index === messages.length - 1 ? '...' : '')
						)}
					</div>
				</article>
			{:else}
				<div class="flex justify-end">
					<div class="max-w-[92%] rounded-2xl rounded-tr-sm border border-primary/10 bg-primary/5 px-4 py-3 text-[1.05rem] leading-7 text-primary">
						{message.content}
					</div>
				</div>
			{/if}
		{/each}

		{#if errorMessage}
			<p class="rounded-xl bg-destructive/5 px-4 py-3 text-sm text-destructive border border-destructive/20">
				{errorMessage}
			</p>
		{/if}

		{#if sessionId && options.length > 0}
			<div class="grid gap-2.5 pt-2 sm:grid-cols-2">
				{#each options as option, optionIndex (`${option}-${optionIndex}`)}
					<button
						class="h-auto min-h-11 w-full rounded-xl border border-border/40 bg-background/50 px-4 py-3 text-left font-sans text-[1rem] leading-7 break-words whitespace-normal text-foreground/90 transition-all hover:border-primary/40 hover:bg-primary/5 hover:text-primary"
						onclick={() => sendMessage(option)}
						disabled={isLoading}
					>
						{option}
					</button>
				{/each}
			</div>
		{/if}
	</div>
</div>

<div
	class="fixed inset-x-0 bottom-0 z-20 border-t border-border/40 bg-background/90 pb-[max(env(safe-area-inset-bottom),0.5rem)] pt-2 backdrop-blur supports-[backdrop-filter]:bg-background/80 lg:left-[16rem]"
>
	<div class="pointer-events-auto mx-auto w-full max-w-4xl px-3 md:px-6">
		{#if !sessionId}
			<div class="flex justify-center py-1">
				<Button
					class="h-11 rounded-full bg-primary/90 px-8 font-sans text-sm tracking-widest text-primary-foreground shadow-md shadow-primary/15 hover:bg-primary"
					onclick={startChapter}
					disabled={isLoading}
				>
					{isLoading ? '启动中...' : '开始阅读'}
				</Button>
			</div>
		{:else}
			<div class="rounded-xl border border-border/45 bg-background/72 px-2 py-2">
				<div class="flex items-center gap-2">
					<Input
						class="h-10 flex-1 rounded-lg border-0 bg-transparent px-2.5 text-[1rem] font-sans shadow-none focus-visible:border-0 focus-visible:ring-0 focus-visible:outline-none"
						bind:value={inputValue}
						placeholder="写下你的回应..."
						onkeydown={(event) => {
							if (event.key === 'Enter') {
								event.preventDefault();
								sendMessage();
							}
						}}
						disabled={isLoading}
					/>
					<Button
						size="icon"
						class="size-9 rounded-full bg-primary/90 text-primary-foreground hover:bg-primary"
						onclick={() => sendMessage()}
						disabled={isLoading || !inputValue.trim()}
						aria-label="发送"
					>
						<SendHorizontal class="size-4" />
					</Button>
				</div>
			</div>
		{/if}
	</div>
</div>

<style>
	:global(.markdown-content > *:first-child) {
		margin-top: 0;
	}

	:global(.markdown-content > *:last-child) {
		margin-bottom: 0;
	}

	:global(.markdown-content p + p) {
		margin-top: 0.6rem;
	}

	:global(.markdown-content ul),
	:global(.markdown-content ol) {
		margin: 0.55rem 0;
		padding-left: 1.2rem;
	}

	:global(.markdown-content li + li) {
		margin-top: 0.2rem;
	}

	:global(.markdown-content code) {
		border: 1px solid oklch(0.9 0.01 82 / 0.6);
		border-radius: 0.4rem;
		padding: 0.05rem 0.35rem;
		background: oklch(0.98 0.01 86 / 0.7);
		font-size: 0.85em;
	}

	:global(.markdown-content pre) {
		margin: 0.65rem 0;
		overflow-x: auto;
		border: 1px solid oklch(0.9 0.01 82 / 0.8);
		border-radius: 0.8rem;
		padding: 0.65rem 0.75rem;
		background: oklch(0.99 0.01 86 / 0.9);
	}

	:global(.markdown-content pre code) {
		border: 0;
		padding: 0;
		background: transparent;
	}

	:global(.markdown-content a) {
		text-decoration: underline;
		text-decoration-thickness: 1px;
		text-underline-offset: 3px;
	}

	:global(.markdown-content blockquote) {
		margin: 0.65rem 0;
		border-left: 2px solid oklch(0.86 0.01 82);
		padding-left: 0.7rem;
		color: oklch(0.48 0.02 80);
	}
</style>
