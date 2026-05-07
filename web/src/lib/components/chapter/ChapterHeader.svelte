<script lang="ts">
	import PageBackToolbar from '$lib/components/ui/page-back-toolbar.svelte';
	import PageTopToolbar from '$lib/components/ui/page-top-toolbar.svelte';
	import type { Snippet } from 'svelte';

	let {
		title,
		subtitle,
		soulerId,
		children
	}: {
		title: string;
		subtitle?: string | null;
		soulerId: string;
		children?: Snippet;
	} = $props();
</script>

<PageTopToolbar {title} backHref={`/bookshelf/${soulerId}`} class="md:hidden">
	{#if children}
		{@render children()}
	{/if}
</PageTopToolbar>
<PageBackToolbar {title} backHref={`/bookshelf/${soulerId}`}>
	{#if children}
		{@render children()}
	{/if}
</PageBackToolbar>

<header class="mb-6 hidden md:block">
	<h1 class="font-serif text-xl leading-tight text-primary md:text-2xl">{title}</h1>
	{#if subtitle}
		<p class="mt-2 text-sm leading-7 text-muted-foreground/80">{subtitle}</p>
	{/if}
</header>
