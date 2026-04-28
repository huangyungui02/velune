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
	class="fixed right-0 bottom-0 left-0 z-20 bg-background/90 pt-0.5 pb-[max(env(safe-area-inset-bottom),0.28rem)] backdrop-blur supports-[backdrop-filter]:bg-background/80 lg:right-[max((100vw-80rem)/2,0px)] lg:left-[calc(max((100vw-80rem)/2,0px)+16rem)]"
>
	<div class="pointer-events-auto mx-auto w-full max-w-4xl px-3 md:px-6">
		{#if !sessionId}
			<div class="flex justify-center py-1">
				<Button
					class="h-11 rounded-full bg-primary/90 px-8 font-sans text-sm tracking-widest text-primary-foreground shadow-md shadow-primary/15 hover:bg-primary"
					onclick={onStart}
					disabled={isLoading}
				>
					{isLoading ? '启动中...' : '开始阅读'}
				</Button>
			</div>
		{:else}
			<div class="rounded-xl border border-border/45 bg-background/72 px-2 py-2">
				<div class="flex items-center gap-2">
					<Input
						class="h-10 flex-1 rounded-lg border-0 bg-transparent px-2.5 font-sans text-[1rem] shadow-none focus-visible:border-0 focus-visible:ring-0 focus-visible:outline-none"
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
						class="size-9 rounded-full bg-primary/90 text-primary-foreground hover:bg-primary"
						onclick={onSend}
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
