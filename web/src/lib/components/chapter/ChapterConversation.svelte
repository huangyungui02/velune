<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
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
	let historyPanelHidden = $state(false);
	let shouldFollowMessages = $state(false);
	let programmaticScrollUntil = 0;

	function scrollToLatestMessage(behavior: ScrollBehavior = 'auto') {
		if (!shouldFollowMessages || !messageContainer?.lastElementChild) {
			return;
		}

		programmaticScrollUntil = Date.now() + 1200;
		messageContainer.lastElementChild.scrollIntoView({ behavior, block: 'start' });
	}

	function getMainScrollContainer() {
		return messageContainer?.closest<HTMLElement>('[data-main-scroll-container]') ?? null;
	}

	function eventStartedInMainScroll(event: Event) {
		const container = getMainScrollContainer();
		if (!container) {
			return false;
		}

		return event.composedPath().includes(container);
	}

	function pauseMessageFollowing(event?: Event) {
		if (event && !eventStartedInMainScroll(event)) {
			return;
		}

		shouldFollowMessages = false;
	}

	function handleMainScroll(event: Event) {
		if (!controller.isLoading || Date.now() <= programmaticScrollUntil) {
			return;
		}

		pauseMessageFollowing(event);
	}

	function toHistoryDate(value: string) {
		const date = new Date(value);
		if (Number.isNaN(date.getTime())) {
			return null;
		}

		return date;
	}

	function formatHistoryDate(value: string) {
		const date = toHistoryDate(value);
		if (!date) {
			return '时间未知';
		}

		return new Intl.DateTimeFormat('zh-CN', {
			year: 'numeric',
			month: 'long',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		}).format(date);
	}

	function formatHistoryCount(count: number) {
		return `${count} 条消息`;
	}

	function formatHistoryLabel(history: ChapterHistoryItem) {
		const date = toHistoryDate(history.updatedAt);
		if (!date) {
			return `时间未知，${formatHistoryCount(history.messageCount)}`;
		}

		return `${formatHistoryDate(history.updatedAt)}，${formatHistoryCount(history.messageCount)}`;
	}

	function continueHistory() {
		if (!selectedHistoryId) {
			return;
		}

		historyPanelHidden = true;
		const path = resolve(`/bookshelf/${souler.id}/chapter/${chapter.id}`);
		const query = new URLSearchParams({ session: selectedHistoryId });
		goto(`${path}?${query.toString()}`);
	}

	function clearHistorySelection() {
		selectedHistoryId = null;
	}

	function startNewChapter() {
		historyPanelHidden = true;
		selectedHistoryId = null;
		shouldFollowMessages = true;
		void controller.startChapter();
	}

	function selectOption(option: string) {
		shouldFollowMessages = true;
		void controller.sendMessage(option);
	}

	function sendMessage() {
		shouldFollowMessages = true;
		void controller.sendMessage();
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
	let showHistoryRecords = $derived(
		!historyPanelHidden &&
			!controller.sessionId &&
			!controller.isLoading &&
			controller.messages.length === 0 &&
			chapterHistories.length > 0
	);
</script>

<svelte:window
	onclick={clearHistorySelection}
	onwheel={pauseMessageFollowing}
	ontouchmove={pauseMessageFollowing}
	onscroll={handleMainScroll}
/>

<div
	class="pt-[calc(env(safe-area-inset-top)+3.4rem)] pb-[calc(env(safe-area-inset-bottom)+3.8rem)] md:pt-2 md:pb-[4.5rem]"
>
	<ChapterHeader title={chapter.title} subtitle={chapter.subtitle} soulerId={souler.id} />

	<div class="space-y-5">
		{#if showHistoryRecords}
			<section class="px-5 pt-2 md:px-4">
				<p class="pb-5 font-sans text-[0.78rem] tracking-[0.18em] text-muted-foreground/58">
					阅读记录
				</p>
				<div class="space-y-1">
					{#each chapterHistories as history (history.id)}
						<button
							type="button"
							class={[
								'flex min-h-12 w-full items-center justify-between gap-3 rounded-xl px-3.5 py-2.5 text-left transition-colors',
								selectedHistoryId === history.id
									? 'bg-primary/8 text-primary'
									: 'text-muted-foreground hover:bg-muted/24 hover:text-foreground'
							]}
							aria-label={formatHistoryLabel(history)}
							aria-pressed={selectedHistoryId === history.id}
							onclick={(event) => {
								event.stopPropagation();
								selectedHistoryId = selectedHistoryId === history.id ? null : history.id;
							}}
						>
							<span class="min-w-0 font-sans text-[0.98rem] leading-none tabular-nums">
								{formatHistoryDate(history.updatedAt)}
							</span>
							<span class="shrink-0 font-sans text-sm text-current/62">
								{formatHistoryCount(history.messageCount)}
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
			onSelect={selectOption}
		/>
	</div>
</div>

<ConversationComposer
	sessionId={controller.sessionId}
	isLoading={controller.isLoading}
	canContinue={Boolean(selectedHistoryId)}
	bind:inputValue={controller.inputValue}
	onStart={startNewChapter}
	onContinue={chapterHistories.length > 0 ? continueHistory : undefined}
	onSend={sendMessage}
/>
