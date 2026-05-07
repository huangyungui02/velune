<script lang="ts">
	import ChevronLeft from '@lucide/svelte/icons/chevron-left';
	import { Button } from '$lib/components/ui/button/index.js';
	import { goBack } from '$lib/navigation/back';
	import { cn } from '$lib/utils.js';
	import type { Snippet } from 'svelte';

	let {
		title,
		backHref = '/bookshelf',
		backLabel = '返回',
		preferHistoryBack = true,
		class: className,
		children
	}: {
		title: string;
		backHref?: string;
		backLabel?: string;
		preferHistoryBack?: boolean;
		class?: string;
		children?: Snippet;
	} = $props();

	function handleBack() {
		void goBack({ fallbackHref: backHref, preferHistoryBack });
	}
</script>

<header
	class={cn(
		'fixed inset-x-0 top-0 z-40 border-b border-border/35 bg-background/70 backdrop-blur-md supports-[backdrop-filter]:bg-background/68',
		className
	)}
>
	<div
		class="grid grid-cols-[2.25rem_1fr_2.25rem] items-center gap-2 px-3 pt-[max(env(safe-area-inset-top),0.4rem)] pb-2"
	>
		<Button
			type="button"
			variant="ghost"
			size="icon-sm"
			class="size-9 rounded-full text-muted-foreground/75 hover:text-primary"
			aria-label={backLabel}
			onclick={handleBack}
		>
			<ChevronLeft class="size-4" />
		</Button>
		<h1
			class="min-w-0 overflow-x-hidden overflow-y-visible px-1 text-center font-serif text-sm leading-[1.2] text-ellipsis whitespace-nowrap text-primary/92"
		>
			{title}
		</h1>
		{#if children}
			{@render children()}
		{:else}
			<span class="size-9" aria-hidden="true"></span>
		{/if}
	</div>
</header>
