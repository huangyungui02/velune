<script lang="ts">
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
	</header>

	{#if data.bookshelf?.length}
		<div class="grid gap-x-6 gap-y-9 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
			{#each data.bookshelf as item (item.id)}
				<a
					href={`/bookshelf/${item.soulerId}`}
					class="group block rounded-3xl p-1 transition duration-300 hover:-translate-y-1"
				>
					<div
						class="relative aspect-[3/4] overflow-hidden rounded-[1.45rem] bg-muted/35 shadow-[0_18px_36px_-24px_oklch(0.24_0.03_57_/_0.55)]"
					>
						{#if item.imageUrl}
							<img
								src={item.imageUrl}
								alt={item.soulerName}
								class="h-full w-full object-cover transition duration-500 group-hover:scale-[1.02]"
							/>
						{:else}
							<div class="grid h-full place-items-center text-xs text-muted-foreground">无图</div>
						{/if}
					</div>
					<div class="mt-3 space-y-1 px-1 text-center">
						<h2 class="truncate text-[1.08rem] leading-7 text-foreground/95 transition group-hover:text-primary">
							{item.soulerName}
						</h2>
						{#if item.lastSessionTitle}
							<p class="line-clamp-2 text-sm leading-6 text-muted-foreground">{item.lastSessionTitle}</p>
						{:else}
							<p class="text-sm leading-6 text-muted-foreground">点击开始阅读章节</p>
						{/if}
					</div>
				</a>
			{/each}
		</div>
	{:else}
		<div class="rounded-2xl bg-muted/25 px-5 py-9 text-sm text-muted-foreground">
			还没有共鸣人物。先去移动端生成 Echo 或开启聊天，书架会自动出现。
		</div>
	{/if}
</section>
