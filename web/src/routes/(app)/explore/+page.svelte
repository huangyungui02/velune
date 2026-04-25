<script lang="ts">
	import * as Card from '$lib/components/ui/card/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import SoulerBookCard from '$lib/components/souler/SoulerBookCard.svelte';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
</script>

<svelte:head>
	<title>Velune · 发现</title>
</svelte:head>

<section class="space-y-8">
	<header class="space-y-2">
		<h1 class="text-3xl leading-tight text-primary">发现</h1>
		<p class="text-sm text-muted-foreground">与所有 soulers 相遇，从一张封面开始。</p>
		<Separator class="mt-3" />
	</header>

	{#if data.soulers.length > 0}
		<div class="grid grid-cols-2 gap-x-4 gap-y-8 lg:grid-cols-4">
			{#each data.soulers as souler (souler.id)}
				<SoulerBookCard
					class="mx-auto w-full max-w-[10.5rem] lg:max-w-[11.5rem]"
					href={`/bookshelf/${souler.id}`}
					name={souler.name}
					imageUrl={souler.imageUrl}
					tags={souler.tags}
				/>
			{/each}
		</div>
	{:else}
		<div class="px-2 py-8 text-sm text-muted-foreground/70">还没有可发现的人物。</div>
	{/if}
</section>
