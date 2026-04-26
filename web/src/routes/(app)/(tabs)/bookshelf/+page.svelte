<script lang="ts">
	import { Separator } from '$lib/components/ui/separator/index.js';
	import SoulerBookCard from '$lib/components/souler/SoulerBookCard.svelte';
	import type { BookshelfItem } from '$lib/types';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	function getMobileBookshelfHref(item: BookshelfItem) {
		if (!item.lastSessionId || !item.lastChapterId) {
			return `/bookshelf/${item.soulerId}`;
		}
		const query = new URLSearchParams({ session: item.lastSessionId });
		return `/bookshelf/${item.soulerId}/chapter/${item.lastChapterId}?${query.toString()}`;
	}
</script>

<svelte:head>
	<title>Velune · 书架</title>
</svelte:head>

<section class="space-y-8">
	<header class="space-y-2">
		<h1 class="text-3xl leading-tight text-primary">书架</h1>
		<Separator class="mt-3" />
	</header>

	{#if data.bookshelf?.length}
		<div class="space-y-3 md:hidden">
			{#each data.bookshelf as item (item.id)}
				<a
					href={getMobileBookshelfHref(item)}
					class="group flex items-start gap-4 rounded-2xl px-2 py-2 transition hover:bg-primary/5"
				>
					<div
						class="relative h-[7.5rem] w-[5.625rem] shrink-0 overflow-hidden rounded-xl bg-muted/20"
					>
						{#if item.imageUrl}
							<img
								src={item.imageUrl}
								alt={item.soulerName}
								class="h-full w-full object-cover transition duration-500 group-hover:scale-[1.02]"
							/>
						{:else}
							<div class="grid h-full place-items-center text-xs text-muted-foreground/60">
								无图
							</div>
						{/if}
					</div>
					<div class="min-w-0 flex-1 py-1">
						<h2
							class="truncate font-hand text-[1.52rem] leading-7 text-foreground transition group-hover:text-primary"
						>
							{item.soulerName}
						</h2>
						<p class="mt-8 truncate text-sm leading-6 text-muted-foreground/80">
							章节 · {item.lastSessionTitle || '点击开始阅读章节'}
						</p>
					</div>
				</a>
			{/each}
		</div>

		<div class="hidden gap-x-6 gap-y-9 md:grid md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
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
