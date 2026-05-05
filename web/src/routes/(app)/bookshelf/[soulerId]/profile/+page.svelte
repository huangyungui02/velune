<script lang="ts">
	import { Badge } from '$lib/components/ui/badge/index.js';
	import PageBackToolbar from '$lib/components/ui/page-back-toolbar.svelte';
	import PageTopToolbar from '$lib/components/ui/page-top-toolbar.svelte';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	const chaptersHref = $derived(`/bookshelf/${data.souler.id}`);
</script>

<svelte:head>
	<title>Velune Folio · {data.souler.name}</title>
</svelte:head>

<section class="space-y-8 pt-[calc(env(safe-area-inset-top)+3.4rem)] md:pt-0">
	<PageTopToolbar title={data.souler.name} backHref={chaptersHref} class="md:hidden" />
	<PageBackToolbar title={data.souler.name} backHref={chaptersHref} />

	<header class="hidden md:block">
		<p class="mb-2 font-sans text-[0.72rem] tracking-[0.24em] text-muted-foreground/64">
			人物简介
		</p>
		<h1 class="font-serif text-2xl leading-tight text-primary">{data.souler.name}</h1>
		<Separator class="mt-5" />
	</header>

	<div
		class="grid grid-cols-[7.25rem_minmax(0,1fr)] items-start gap-x-4 gap-y-5 md:grid-cols-[12rem_minmax(0,38rem)] md:gap-x-7 md:gap-y-4"
	>
		<div
			class="relative aspect-[3/4] w-full overflow-hidden rounded-2xl bg-muted/20 shadow-sm md:row-span-2 md:max-w-[13rem] md:rounded-xl"
		>
			{#if data.souler.imageUrl}
				<img src={data.souler.imageUrl} alt={data.souler.name} class="h-full w-full object-cover" />
			{:else}
				<div class="grid h-full place-items-center text-sm text-muted-foreground/60">无图</div>
			{/if}
		</div>

		<div class="min-w-0 py-1">
			<h2 class="font-serif text-xl leading-tight text-primary md:hidden">
				{data.souler.name}
			</h2>

			{#if data.keywords.length > 0}
				<div class="mt-4 flex flex-wrap gap-2 md:mt-0">
					{#each data.keywords as word (word)}
						<Badge
							variant="outline"
							class="rounded-full border-border/60 bg-background/50 px-3 py-1 font-sans text-xs font-normal text-muted-foreground"
						>
							{word}
						</Badge>
					{/each}
				</div>
			{/if}
		</div>

		<p class="col-span-2 text-sm leading-8 text-foreground/80 md:col-span-1 md:col-start-2 md:col-end-3 md:max-w-[64ch]">
			{#if data.souler.bio}
				{data.souler.bio}
			{:else}
				暂无简介。
			{/if}
		</p>
	</div>
</section>
