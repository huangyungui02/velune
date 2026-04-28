<script lang="ts">
	import { tick, untrack } from 'svelte';
	import ChapterHeader from '$lib/components/chapter/ChapterHeader.svelte';
	import ConversationComposer from '$lib/components/chapter/ConversationComposer.svelte';
	import ConversationMessages from '$lib/components/chapter/ConversationMessages.svelte';
	import ConversationOptions from '$lib/components/chapter/ConversationOptions.svelte';
	import { ConversationController } from '$lib/features/chapter/conversation-controller.svelte';
	import type { ConversationMessage } from '$lib/types';

	let {
		souler,
		chapter,
		initialSessionId,
		initialMessages
	}: {
		souler: { id: string; name: string };
		chapter: { id: string; title: string; subtitle?: string | null };
		initialSessionId: string | null;
		initialMessages: ConversationMessage[];
	} = $props();

	let messageContainer = $state<HTMLElement | null>(null);

	function scrollToLatestMessage(behavior: ScrollBehavior = 'auto') {
		if (!messageContainer?.lastElementChild) {
			return;
		}
		messageContainer.lastElementChild.scrollIntoView({ behavior, block: 'start' });
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

<div
	class="pt-[calc(env(safe-area-inset-top)+3.4rem)] pb-[calc(env(safe-area-inset-bottom)+3.8rem)] md:pt-2 md:pb-[4.5rem]"
>
	<ChapterHeader title={chapter.title} subtitle={chapter.subtitle} soulerId={souler.id} />

	<div class="space-y-5">
		<ConversationMessages
			messages={controller.messages}
			isLoading={controller.isLoading}
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
	bind:inputValue={controller.inputValue}
	onStart={() => controller.startChapter()}
	onSend={() => controller.sendMessage()}
/>
