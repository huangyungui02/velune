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
		'hidden md:sticky md:top-4 md:z-30 md:!-mt-6 lg:!-mt-8 md:mb-8 md:flex md:h-12 md:items-center md:justify-between',
		className
	)}
	aria-label={backLabel}
>
	<div class="flex items-center">
		<button
			type="button"
			class="group flex size-10 items-center justify-center rounded-full bg-background/50 backdrop-blur-xl border border-foreground/5 shadow-[0_2px_10px_-3px_rgba(0,0,0,0.1)] transition-all duration-300 hover:scale-105 hover:bg-background/70 active:scale-95"
			aria-label={backLabel}
			onclick={handleBack}
		>
			<ChevronLeft
				class="size-5 text-foreground/70 transition-transform group-hover:-translate-x-0.5"
				strokeWidth={2}
			/>
		</button>
	</div>

	{#if children}
		<div class="flex items-center gap-4 text-muted-foreground/70 transition-colors">
			{@render children()}
		</div>
	{/if}
</nav>
