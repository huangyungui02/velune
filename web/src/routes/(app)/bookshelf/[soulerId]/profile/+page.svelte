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



	<div
		class="grid grid-cols-[7.25rem_minmax(0,1fr)] items-start gap-x-4 gap-y-5 md:grid-cols-[14rem_minmax(0,1fr)] md:gap-x-12"
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
		<div class="min-w-0 py-1 md:hidden">
			<h1 class="font-serif text-xl leading-tight text-primary">
				{data.souler.name}
			</h1>

			{#if data.keywords.length > 0}
				<div class="mt-4 flex flex-wrap gap-2">
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

		<!-- Right Column: Bio & Tags -->
		<div
			class="col-span-2 space-y-4 md:col-span-1 md:col-start-2 md:row-start-1 md:space-y-6 md:pt-1"
		>
			<p class="text-sm leading-8 text-foreground/80 md:max-w-[64ch]">
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
	</div>
</section>
