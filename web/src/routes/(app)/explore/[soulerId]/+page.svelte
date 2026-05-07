<script lang="ts">
	import { resolve } from '$app/paths';
	import { onMount } from 'svelte';
	import { Badge } from '$lib/components/ui/badge/index.js';
	import PageBackToolbar from '$lib/components/ui/page-back-toolbar.svelte';
	import PageTopToolbar from '$lib/components/ui/page-top-toolbar.svelte';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	const exploreHref = '/explore';

	function scrollMainContainerToTop() {
		if (typeof document === 'undefined') {
			return;
		}

		document
			.querySelector<HTMLElement>('[data-main-scroll-container]')
			?.scrollTo({ top: 0, behavior: 'auto' });
	}

	function formatChapterNumber(seq: number) {
		const value = Number(seq);
		if (!Number.isFinite(value) || value <= 0) {
			return '00';
		}

		return String(Math.trunc(value)).padStart(2, '0');
	}

	onMount(() => {
		scrollMainContainerToTop();
	});

</script>

<svelte:head>
	<title>Velune Folio · {data.souler.name}</title>
</svelte:head>

<section class="mx-auto max-w-5xl space-y-10 pt-[calc(env(safe-area-inset-top)+3.4rem)] md:pt-0">
	<PageTopToolbar title={data.souler.name} backHref={exploreHref} class="md:hidden" />
	<PageBackToolbar title={data.souler.name} backHref={exploreHref} />



	<section
		class="grid grid-cols-[6.5rem_minmax(0,1fr)] items-start gap-x-4 gap-y-6 md:grid-cols-[14rem_minmax(0,1fr)] md:gap-x-12"
		aria-label="人物资料"
	>
		<!-- Left Column: Avatar + Name + Tags (Desktop) -->
		<div class="col-span-1 flex flex-col gap-6 md:col-span-1 md:items-center">
			<div
				class="relative aspect-[3/4] w-full overflow-hidden rounded-2xl bg-muted/20 shadow-sm md:rounded-xl"
			>
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

			<!-- Desktop Name -->
			<div class="hidden md:flex md:flex-col md:items-center">
				<h1 class="font-serif text-2xl leading-tight text-primary">
					{data.souler.name}
				</h1>
			</div>
		</div>

		<!-- Mobile Name & Tags (Right of avatar) -->
		<div class="min-w-0 space-y-3 pt-1 md:hidden">
			<h1 class="font-serif text-2xl leading-tight text-primary">
				{data.souler.name}
			</h1>

			{#if data.keywords.length > 0}
				<div class="flex flex-wrap gap-2">
					{#each data.keywords as word (word)}
						<Badge
							variant="outline"
							class="rounded-full border-border/60 bg-background/50 px-2.5 py-0.5 font-sans text-xs font-normal text-muted-foreground"
						>
							{word}
						</Badge>
					{/each}
				</div>
			{/if}
		</div>

		<!-- Right Column: Bio & Tags -->
		<div
			class="col-span-2 space-y-4 md:col-span-1 md:col-start-2 md:row-start-1 md:space-y-6 md:pt-1"
		>
			<p
				class="text-[0.95rem] leading-7 text-foreground/80 md:max-w-[64ch] md:text-[0.95rem] md:leading-8"
			>
				{#if data.souler.bio}
					{data.souler.bio}
				{:else}
					暂无简介。
				{/if}
			</p>

			<!-- Desktop Tags (Below bio) -->
			{#if data.keywords.length > 0}
				<div class="hidden md:flex md:flex-wrap md:gap-2">
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
	</section>

	<section class="max-w-3xl border-t border-border/45 pt-4" aria-label="章节">
		{#if data.chapters.length}
			<div class="divide-y divide-border/45">
				{#each data.chapters as chapter (chapter.id)}
					<a
						href={resolve(`/bookshelf/${data.souler.id}/chapter/${chapter.id}`)}
						class="group block py-5 transition-colors hover:bg-muted/18 md:px-2"
					>
						<p class="mb-2 text-[0.72rem] tracking-[0.24em] text-muted-foreground/70">
							{formatChapterNumber(chapter.seq)}
						</p>
						<h3
							class="text-xl leading-7 text-foreground transition-colors group-hover:text-primary"
						>
							{chapter.title}
						</h3>
						{#if chapter.subtitle}
							<p class="mt-2 max-w-2xl text-sm leading-6 text-muted-foreground">
								{chapter.subtitle}
							</p>
						{/if}
					</a>
				{/each}
			</div>
		{:else}
			<div class="px-1 py-4 text-sm text-muted-foreground/70">当前人物还没有章节。</div>
		{/if}
	</section>
</section>
