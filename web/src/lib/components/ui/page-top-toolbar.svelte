<script lang="ts">
	import ChevronLeft from '@lucide/svelte/icons/chevron-left';
	import { Button } from '$lib/components/ui/button/index.js';
	import { cn } from '$lib/utils.js';
	import type { Snippet } from 'svelte';

	let {
		title,
		backHref = '/bookshelf',
		backLabel = '返回',
		class: className,
		children
	}: {
		title: string;
		backHref?: string;
		backLabel?: string;
		class?: string;
		children?: Snippet;
	} = $props();
</script>

<header
	class={cn(
		'fixed inset-x-0 top-0 z-40 border-b border-border/35 bg-background/70 backdrop-blur-md supports-[backdrop-filter]:bg-background/68',
		className
	)}
>
	<div class="grid grid-cols-[2.25rem_1fr_2.25rem] items-center gap-2 px-3 pb-2 pt-[max(env(safe-area-inset-top),0.4rem)]">
		<Button
			href={backHref}
			variant="ghost"
			size="icon-sm"
			class="size-9 rounded-full text-muted-foreground/75 hover:text-primary"
			aria-label={backLabel}
		>
			<ChevronLeft class="size-4" />
		</Button>
		<h1
			class="min-w-0 overflow-x-hidden overflow-y-visible text-ellipsis whitespace-nowrap px-1 text-center font-hand text-base leading-[1.2] text-primary/92"
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
