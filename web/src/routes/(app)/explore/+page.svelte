<script lang="ts">
	import { Button } from '$lib/components/ui/button/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import SoulerBookCard from '$lib/components/souler/SoulerBookCard.svelte';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	const featuredHref = '/explore?tab=featured';

	function latestHref(page: number) {
		const params = new URLSearchParams({ tab: 'latest' });
		if (page > 1) {
			params.set('page', String(page));
		}
		return `/explore?${params.toString()}`;
	}
</script>

<svelte:head>
	<title>Velune · 发现</title>
</svelte:head>

<section class="space-y-8">
	<header class="space-y-2">
		<div class="flex flex-wrap items-start justify-between gap-4">
			<div class="space-y-2">
				<h1 class="text-3xl leading-tight text-primary">发现</h1>
				<p class="text-sm text-muted-foreground">与所有 soulers 相遇，从一张封面开始。</p>
			</div>
			<div class="inline-flex rounded-2xl border border-border/50 bg-muted/20 p-1">
				<Button
					href={featuredHref}
					variant={data.activeTab === 'featured' ? 'default' : 'ghost'}
					size="sm"
					class="rounded-xl px-4"
					data-sveltekit-preload-data="tap"
				>
					精选
				</Button>
				<Button
					href={latestHref(1)}
					variant={data.activeTab === 'latest' ? 'default' : 'ghost'}
					size="sm"
					class="rounded-xl px-4"
					data-sveltekit-preload-data="tap"
				>
					最新
				</Button>
			</div>
		</div>
		<Separator class="mt-3" />
	</header>

	{#if data.activeTab === 'featured'}
		{#if data.featuredSections.length > 0}
			<div class="space-y-10">
				{#each data.featuredSections as section (section.id)}
					<section class="space-y-4">
						<div class="px-1">
							<h2 class="font-hand text-[1.9rem] leading-tight text-primary md:text-[2.2rem]">
								{section.title}
							</h2>
							{#if section.subtitle}
								<p class="mt-1 text-sm text-muted-foreground/80">{section.subtitle}</p>
							{/if}
						</div>

						<div class="scrollbar-soft -mx-1 overflow-x-auto overscroll-x-contain pb-3 pl-1">
							<div
								class="grid min-w-max auto-cols-[minmax(9.5rem,10.75rem)] grid-flow-col gap-4 pr-4 md:auto-cols-[minmax(10rem,11.5rem)]"
							>
								{#each section.soulers as souler (souler.id)}
									<SoulerBookCard
										href={`/bookshelf/${souler.id}`}
										name={souler.name}
										imageUrl={souler.imageUrl}
										tags={souler.tags}
									/>
								{/each}
							</div>
						</div>
					</section>
				{/each}
			</div>
		{:else}
			<div class="px-2 py-8 text-sm text-muted-foreground/70">还没有可展示的精选分组。</div>
		{/if}
	{:else if data.latestItems.length > 0}
		<div class="grid grid-cols-2 gap-x-4 gap-y-8 lg:grid-cols-4">
			{#each data.latestItems as souler (souler.id)}
				<SoulerBookCard
					class="mx-auto w-full max-w-[10.5rem] lg:max-w-[11.5rem]"
					href={`/bookshelf/${souler.id}`}
					name={souler.name}
					imageUrl={souler.imageUrl}
					tags={souler.tags}
				/>
			{/each}
		</div>

		<div class="flex items-center justify-between border-t border-border/40 pt-2">
			<p class="text-xs text-muted-foreground/80">第 {data.latestPage} 页 · 每页 20 人</p>
			<div class="flex items-center gap-2">
				{#if data.latestPage > 1}
					<Button
						href={latestHref(data.latestPage - 1)}
						variant="outline"
						size="sm"
						class="rounded-xl"
						data-sveltekit-preload-data="tap"
					>
						上一页
					</Button>
				{:else}
					<Button variant="outline" size="sm" class="rounded-xl" disabled>上一页</Button>
				{/if}

				{#if data.hasLatestNextPage}
					<Button
						href={latestHref(data.latestPage + 1)}
						variant="outline"
						size="sm"
						class="rounded-xl"
						data-sveltekit-preload-data="tap"
					>
						下一页
					</Button>
				{:else}
					<Button variant="outline" size="sm" class="rounded-xl" disabled>下一页</Button>
				{/if}
			</div>
		</div>
	{:else}
		<div class="px-2 py-8 text-sm text-muted-foreground/70">还没有可发现的人物。</div>
	{/if}
</section>
