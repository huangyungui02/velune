<script lang="ts">
	import ChevronLeft from '@lucide/svelte/icons/chevron-left';
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

<nav
	class={cn(
		'hidden md:sticky md:top-0 md:z-30 md:-mx-2 md:mb-8 md:flex md:h-16 md:items-center md:justify-between md:bg-background/80 md:px-2 md:backdrop-blur-md',
		className
	)}
	aria-label={backLabel}
>
	<div class="flex items-center gap-6">
		<button
			type="button"
			class="group flex h-8 items-center gap-1.5 pr-2 text-[0.8rem] text-muted-foreground/60 transition-all hover:text-primary"
			aria-label={backLabel}
			onclick={handleBack}
		>
			<ChevronLeft
				class="size-4 transition-transform group-hover:-translate-x-0.5"
				strokeWidth={1.5}
			/>
			<span class="tracking-widest">{backLabel}</span>
		</button>

		{#if title}
			<span
				class="hidden max-w-[200px] truncate text-[0.75rem] tracking-[0.2em] text-muted-foreground/40 md:block"
			>
				{title}
			</span>
		{/if}
	</div>

	{#if children}
		<div class="flex items-center gap-4">
			{@render children()}
		</div>
	{/if}
</nav>
