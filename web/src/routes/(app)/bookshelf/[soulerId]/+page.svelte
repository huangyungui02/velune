<script lang="ts">
	import { resolve } from '$app/paths';
	import { Badge } from '$lib/components/ui/badge/index.js';
	import PageTopToolbar from '$lib/components/ui/page-top-toolbar.svelte';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
</script>

<svelte:head>
	<title>Velune · {data.souler.name}</title>
</svelte:head>

<section class="space-y-7 pt-[calc(env(safe-area-inset-top)+3.4rem)] md:pt-0">
	<PageTopToolbar title={data.souler.name} backHref="/bookshelf" class="md:hidden" />

	<header class="grid grid-cols-[7.25rem_minmax(0,1fr)] items-start gap-x-4 gap-y-4 md:grid-cols-[12rem_1fr] md:gap-6">
		<div class="relative aspect-[3/4] w-full overflow-hidden rounded-2xl bg-muted/20 shadow-sm md:max-w-[13rem]">
			{#if data.souler.imageUrl}
				<img
					src={data.souler.imageUrl}
					alt={data.souler.name}
					class="h-full w-full object-cover"
				/>
			{:else}
				<div class="grid h-full place-items-center text-sm text-muted-foreground/60">无图</div>
			{/if}
		</div>

		<div class="py-1">
			<div class="space-y-4">
				<h1 class="font-serif text-xl leading-tight text-primary md:text-2xl">{data.souler.name}</h1>

				{#if data.keywords.length > 0}
					<div class="flex flex-wrap gap-2">
						{#each data.keywords as word (word)}
							<Badge variant="outline" class="rounded-full bg-background/50 border-border/60 px-3 py-1 font-sans text-xs font-normal text-muted-foreground">
								{word}
							</Badge>
						{/each}
					</div>
				{/if}
			</div>

			<p class="mt-4 hidden text-sm leading-8 text-foreground/80 md:block">
				{#if data.souler.bio}
					{data.souler.bio}
				{:else}
					暂无简介。
				{/if}
			</p>
		</div>

		<p class="col-span-2 text-sm leading-8 text-foreground/80 md:hidden">
			{#if data.souler.bio}
				{data.souler.bio}
			{:else}
				暂无简介。
			{/if}
		</p>
	</header>

	<section class="space-y-3">
		<h2 class="text-xl text-primary">章节</h2>
		<Separator />

		{#if data.chapters.length}
			<div class="grid gap-3 pt-4">
				{#each data.chapters as chapter (chapter.id)}
					<a
						href={resolve(`/bookshelf/${data.souler.id}/chapter/${chapter.id}`)}
						class="block group px-4 py-3 border-l-2 border-transparent hover:border-primary/40 transition"
					>
						<p class="text-xs font-sans tracking-widest text-muted-foreground/60 mb-1">CHAPTER {chapter.seq}</p>
						<h3 class="text-xl leading-7 text-foreground transition group-hover:text-primary">{chapter.title}</h3>
						{#if chapter.subtitle}
							<p class="text-sm leading-6 text-muted-foreground mt-2">{chapter.subtitle}</p>
						{/if}
					</a>
				{/each}
			</div>
		{:else}
			<div class="px-4 py-8 text-sm text-muted-foreground/70">
				当前人物还没有章节。
			</div>
		{/if}
	</section>
</section>
