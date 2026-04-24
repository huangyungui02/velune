<script lang="ts">
	import { tick } from 'svelte';
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
		messages.length;
		tick().then(() => {
			if (messageContainer) {
				messageContainer.scrollTop = messageContainer.scrollHeight;
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

	function extractChapterBody(rawContent: string) {
		const marker = rawContent.indexOf('---JSON---');
		if (marker < 0) {
			return rawContent.trim();
		}
		return rawContent.slice(0, marker).trim();
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
			messages = [
				{
					role: 'assistant',
					content: extractChapterBody(payload.assistant_message.content)
				}
			];
			options = normalizeOptions(payload.options);
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

<section class="space-y-5">
	<header class="space-y-3">
		<a
			href={`/bookshelf/${data.souler.id}`}
			class="inline-flex items-center rounded-full border border-border/70 px-3 py-1 text-xs text-muted-foreground transition hover:bg-accent/30"
			>返回人物</a
		>
		<h1 class="text-3xl leading-tight text-primary">{data.chapter.title}</h1>
		<p class="text-sm leading-6 text-muted-foreground">{data.chapter.subtitle}</p>
	</header>

	<div class="space-y-4 rounded-2xl border border-border/70 bg-background/45 p-4 md:p-5">
		<div bind:this={messageContainer} class="max-h-[52vh] space-y-3 overflow-y-auto pr-1">
			{#if messages.length === 0}
				<p
					class="rounded-xl border border-dashed border-border px-3 py-4 text-sm text-muted-foreground"
				>
					点击「开始」，AI 会为你展开第一段叙述。
				</p>
			{/if}

			{#each messages as message, index (`${message.role}-${index}`)}
				<div class={`flex ${message.role === 'user' ? 'justify-end' : 'justify-start'}`}>
					<div
						class={`max-w-[86%] rounded-2xl px-4 py-3 text-sm leading-7 ${
							message.role === 'user'
								? 'border border-primary/20 bg-primary/12 text-foreground'
								: 'border border-border/70 bg-card/90 text-foreground'
						}`}
					>
						{message.content || (isLoading && index === messages.length - 1 ? '...' : '')}
					</div>
				</div>
			{/each}
		</div>

		{#if errorMessage}
			<p class="rounded-xl bg-destructive/10 px-3 py-2 text-sm text-destructive">{errorMessage}</p>
		{/if}

		{#if !sessionId}
			<button
				class="h-11 rounded-xl border border-primary/30 bg-primary px-5 text-sm font-medium text-primary-foreground transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
				onclick={startChapter}
				disabled={isLoading}
			>
				{isLoading ? '启动中...' : '开始'}
			</button>
		{:else}
			<div class="space-y-3">
				<div class="grid gap-2 sm:grid-cols-2">
					{#each options as option, optionIndex (`${option}-${optionIndex}`)}
						<button
							class="min-h-12 rounded-xl border border-border/70 bg-card/80 px-3 py-2 text-left text-sm leading-6 transition hover:border-primary/25 hover:bg-card disabled:cursor-not-allowed disabled:opacity-60"
							onclick={() => sendMessage(option)}
							disabled={isLoading}
						>
							{option}
						</button>
					{/each}
				</div>

				<div class="flex gap-2">
					<input
						class="h-11 flex-1 rounded-xl border border-input bg-background/70 px-3 text-sm transition outline-none focus:border-primary/60"
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
					<button
						class="h-11 rounded-xl border border-primary/30 bg-primary px-4 text-sm font-medium text-primary-foreground transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
						onclick={() => sendMessage()}
						disabled={isLoading || !inputValue.trim()}
					>
						发送
					</button>
				</div>
			</div>
		{/if}
	</div>
</section>
