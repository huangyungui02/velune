<script lang="ts">
	import * as Card from '$lib/components/ui/card/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import SoulerBookCard from '$lib/components/souler/SoulerBookCard.svelte';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
</script>

<svelte:head>
	<title>Velune · 书架</title>
</svelte:head>

<section class="space-y-8">
	<header class="space-y-2">
		<h1 class="text-3xl leading-tight text-primary">书架</h1>
		<p class="text-sm text-muted-foreground">从最近一次共鸣开始，继续读下去。</p>
		<Separator class="mt-3" />
	</header>

	{#if data.bookshelf?.length}
		<div class="grid gap-x-6 gap-y-9 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
			{#each data.bookshelf as item (item.id)}
				<SoulerBookCard
					href={`/bookshelf/${item.soulerId}`}
					name={item.soulerName}
					imageUrl={item.imageUrl}
					subtitle={item.lastSessionTitle}
					fallbackSubtitle="点击开始阅读章节"
				/>
			{/each}
		</div>
	{:else}
		<div class="px-2 py-8 text-sm text-muted-foreground/70">
			还没有共鸣人物。先去移动端生成 Echo 或开启聊天，书架会自动出现。
		</div>
	{/if}
</section>
