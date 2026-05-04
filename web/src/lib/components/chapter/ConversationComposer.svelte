<script lang="ts">
	import SendHorizontal from '@lucide/svelte/icons/send-horizontal';
	import { Button } from '$lib/components/ui/button/index.js';
	import { Input } from '$lib/components/ui/input/index.js';

	let {
		sessionId,
		isLoading,
		inputValue = $bindable(''),
		onStart,
		onSend
	}: {
		sessionId: string | null;
		isLoading: boolean;
		inputValue: string;
		onStart: () => void;
		onSend: () => void;
	} = $props();
</script>

<div
	class="fixed right-0 bottom-0 left-0 z-20 bg-background pt-2 pb-[max(env(safe-area-inset-bottom),0.42rem)] lg:right-[max((100vw-80rem)/2,0px)] lg:left-[calc(max((100vw-80rem)/2,0px)+16rem)]"
>
	<div class="pointer-events-auto mx-auto mb-2 w-full max-w-3xl px-3 md:px-6">
		{#if !sessionId}
			<div class="flex justify-center py-1">
				<Button
					class="h-11 rounded-full bg-primary px-8 font-sans text-sm tracking-widest text-primary-foreground shadow-sm hover:bg-primary/92"
					onclick={onStart}
					disabled={isLoading}
				>
					{isLoading ? '启动中...' : '开始阅读'}
				</Button>
			</div>
		{:else}
			<div
				class="flex min-h-12 items-center gap-1.5 rounded-full border border-border/70 bg-muted/35 px-3 py-1.5"
			>
				<Input
					class="h-9 flex-1 rounded-full border-0 bg-transparent px-1.5 font-sans text-[1rem] shadow-none placeholder:text-muted-foreground/55 focus-visible:border-0 focus-visible:ring-0 focus-visible:outline-none disabled:opacity-60"
					bind:value={inputValue}
					placeholder="写下你的回应..."
					onkeydown={(event) => {
						if (event.key === 'Enter') {
							event.preventDefault();
							onSend();
						}
					}}
					disabled={isLoading}
				/>
				<Button
					size="icon"
					class="size-9 rounded-full bg-primary text-primary-foreground shadow-none hover:bg-primary/92 disabled:bg-muted-foreground/20"
					onclick={onSend}
					disabled={isLoading || !inputValue.trim()}
					aria-label="发送"
				>
					<SendHorizontal class="size-4" />
				</Button>
			</div>
		{/if}
	</div>
</div>
