<script lang="ts">
	import { renderAssistantMarkdown } from '$lib/features/chapter/assistant-content';
	import type { ConversationMessage } from '$lib/types';

	let {
		messages,
		isLoading,
		container = $bindable<HTMLElement | null>(null)
	}: {
		messages: ConversationMessage[];
		isLoading: boolean;
		container: HTMLElement | null;
	} = $props();
</script>

<div class="space-y-5 px-2 md:px-4" bind:this={container}>
	{#if messages.length === 0}
		<p class="py-8 text-center font-sans text-sm tracking-widest text-muted-foreground/60">
			-- 叙述由此展开 --
		</p>
	{/if}

	{#each messages as message, index (`${message.role}-${index}`)}
		{#if message.role === 'assistant'}
			<article class="w-full px-1 text-[1.1rem] leading-8 text-foreground md:px-2">
				<div class="markdown-content">
					<!-- eslint-disable-next-line svelte/no-at-html-tags -->
					{@html renderAssistantMarkdown(
						message.content || (isLoading && index === messages.length - 1 ? '...' : '')
					)}
				</div>
			</article>
		{:else}
			<div class="flex justify-end">
				<div
					class="max-w-[92%] rounded-2xl rounded-tr-sm border border-primary/10 bg-primary/5 px-4 py-3 text-[1.05rem] leading-7 text-primary"
				>
					{message.content}
				</div>
			</div>
		{/if}
	{/each}
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
