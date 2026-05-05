<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import ChevronLeft from '@lucide/svelte/icons/chevron-left';
	import { Button } from '$lib/components/ui/button/index.js';
	import { hasPreviousRoute } from '$lib/stores/navigation-stack';
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

	async function handleBack() {
		if (
			preferHistoryBack &&
			typeof window !== 'undefined' &&
			window.history.length > 1 &&
			hasPreviousRoute(page.url)
		) {
			window.history.back();
			return;
		}

		if (backHref.startsWith('/')) {
			await goto(resolve(backHref as '/'), { keepFocus: true });
			return;
		}

		window.location.assign(backHref);
	}
</script>

<nav
	class={cn(
		'hidden md:sticky md:top-0 md:z-30 md:-mx-1 md:mb-8 md:flex md:h-10 md:items-center md:justify-between md:border-b md:border-border/20 md:bg-background md:px-1',
		className
	)}
	aria-label={backLabel}
>
	<Button
		type="button"
		variant="ghost"
		size="icon-sm"
		class="size-8 rounded-full text-muted-foreground/70 hover:bg-transparent hover:text-primary"
		aria-label={backLabel}
		onclick={handleBack}
	>
		<ChevronLeft class="size-4" />
		<span class="sr-only">{title}</span>
	</Button>

	{#if children}
		{@render children()}
	{/if}
</nav>
