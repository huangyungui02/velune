<script lang="ts">
	import { resolve } from '$app/paths';
	import UserRound from '@lucide/svelte/icons/user-round';
	import PageTopToolbar from '$lib/components/ui/page-top-toolbar.svelte';
	import { Button } from '$lib/components/ui/button/index.js';

	let {
		title,
		subtitle,
		soulerId
	}: {
		title: string;
		subtitle?: string | null;
		soulerId: string;
	} = $props();
</script>

<PageTopToolbar {title} backHref="/bookshelf" class="md:hidden">
	<Button
		href={resolve(`/bookshelf/${soulerId}`)}
		variant="ghost"
		size="icon-sm"
		class="size-9 rounded-full text-muted-foreground/80 hover:text-primary"
		aria-label="人物详情"
	>
		<UserRound class="size-4" />
	</Button>
</PageTopToolbar>

<header class="mb-6 hidden md:block">
	<h1 class="font-serif text-xl leading-tight text-primary md:text-2xl">{title}</h1>
	{#if subtitle}
		<p class="mt-2 text-sm leading-7 text-muted-foreground/80">{subtitle}</p>
	{/if}
</header>
