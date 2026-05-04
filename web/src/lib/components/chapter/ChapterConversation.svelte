<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import Clock3 from '@lucide/svelte/icons/clock-3';
	import MessageCircle from '@lucide/svelte/icons/message-circle';
	import { tick, untrack } from 'svelte';
	import ChapterHeader from '$lib/components/chapter/ChapterHeader.svelte';
	import ConversationComposer from '$lib/components/chapter/ConversationComposer.svelte';
	import ConversationMessages from '$lib/components/chapter/ConversationMessages.svelte';
	import ConversationOptions from '$lib/components/chapter/ConversationOptions.svelte';
	import { ConversationController } from '$lib/features/chapter/conversation-controller.svelte';
	import type { ChapterHistoryItem, ConversationMessage } from '$lib/types';

	let {
		souler,
		chapter,
		initialSessionId,
		initialMessages,
		chapterHistories
	}: {
		souler: { id: string; name: string };
		chapter: { id: string; title: string; subtitle?: string | null };
		initialSessionId: string | null;
		initialMessages: ConversationMessage[];
		chapterHistories: ChapterHistoryItem[];
	} = $props();

	let messageContainer = $state<HTMLElement | null>(null);
	let selectedHistoryId = $state<string | null>(null);

	function scrollToLatestMessage(behavior: ScrollBehavior = 'auto') {
		if (!messageContainer?.lastElementChild) {
			return;
		}
		messageContainer.lastElementChild.scrollIntoView({ behavior, block: 'start' });
	}

	function formatHistoryTime(value: string) {
		const date = new Date(value);
		if (Number.isNaN(date.getTime())) {
			return '时间未知';
		}

		return new Intl.DateTimeFormat('zh-CN', {
			month: 'long',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		}).format(date);
	}

	function continueHistory() {
		if (!selectedHistoryId) {
			return;
		}

		const path = resolve(`/bookshelf/${souler.id}/chapter/${chapter.id}`);
		const query = new URLSearchParams({ session: selectedHistoryId });
		goto(`${path}?${query.toString()}`);
	}

	function clearHistorySelection() {
		selectedHistoryId = null;
	}

	const controller = untrack(
		() =>
			new ConversationController({
				soulerId: souler.id,
				soulerName: souler.name,
				chapterId: chapter.id,
				initialSessionId,
				initialMessages,
				onMessagesChanged: () => {
					tick().then(() => scrollToLatestMessage('smooth'));
				}
			})
	);
</script>

<svelte:window onclick={clearHistorySelection} />

<div
	class="pt-[calc(env(safe-area-inset-top)+3.4rem)] pb-[calc(env(safe-area-inset-bottom)+3.8rem)] md:pt-2 md:pb-[4.5rem]"
>
	<ChapterHeader title={chapter.title} subtitle={chapter.subtitle} soulerId={souler.id} />

	<div class="space-y-5">
		{#if !controller.sessionId && chapterHistories.length > 0}
			<section class="px-2 md:px-4">
				<p class="px-1 pb-2 font-sans text-xs tracking-[0.18em] text-muted-foreground/70">
					阅读记录
				</p>
				<div class="divide-y divide-border/60">
					{#each chapterHistories as history (history.id)}
						<button
							type="button"
							class={[
								'flex w-full items-center gap-4 px-1 py-3 text-left transition',
								selectedHistoryId === history.id
									? 'bg-muted/35 text-primary'
									: 'text-foreground hover:bg-muted/25'
							]}
							aria-label={`${formatHistoryTime(history.updatedAt)}，${history.messageCount} 条消息`}
							aria-pressed={selectedHistoryId === history.id}
							onclick={(event) => {
								event.stopPropagation();
								selectedHistoryId = selectedHistoryId === history.id ? null : history.id;
							}}
						>
							<span
								class={[
									'flex min-w-0 flex-wrap items-center gap-x-4 gap-y-1 text-sm',
									selectedHistoryId === history.id ? 'text-primary' : 'text-muted-foreground'
								]}
							>
								<span class="inline-flex items-center gap-1.5">
									<Clock3 class="size-3.5" />
									{formatHistoryTime(history.updatedAt)}
								</span>
								<span class="inline-flex items-center gap-1.5">
									<MessageCircle class="size-3.5" />
									{history.messageCount} 条消息
								</span>
							</span>
						</button>
					{/each}
				</div>
			</section>
		{/if}

		<ConversationMessages
			messages={controller.messages}
			isLoading={controller.isLoading}
			showEmptyState={chapterHistories.length === 0}
			bind:container={messageContainer}
		/>

		{#if controller.errorMessage}
			<p
				class="mx-2 rounded-xl border border-destructive/20 bg-destructive/5 px-4 py-3 text-sm text-destructive md:mx-4"
			>
				{controller.errorMessage}
			</p>
		{/if}

		<ConversationOptions
			sessionId={controller.sessionId}
			options={controller.options}
			isLoading={controller.isLoading}
			onSelect={(option) => controller.sendMessage(option)}
		/>
	</div>
</div>

<ConversationComposer
	sessionId={controller.sessionId}
	isLoading={controller.isLoading}
	canContinue={Boolean(selectedHistoryId)}
	bind:inputValue={controller.inputValue}
	onStart={() => controller.startChapter()}
	onContinue={chapterHistories.length > 0 ? continueHistory : undefined}
	onSend={() => controller.sendMessage()}
/>
