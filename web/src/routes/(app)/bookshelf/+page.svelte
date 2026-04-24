<script lang="ts">
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
</script>

<svelte:head>
	<title>Velune · 书架</title>
</svelte:head>

<section class="space-y-6">
	<header class="space-y-2">
		<h1 class="text-3xl leading-tight text-primary">书架</h1>
		<p class="text-sm text-muted-foreground">从最近一次共鸣开始，继续读下去。</p>
	</header>

	{#if data.bookshelf?.length}
		<div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
			{#each data.bookshelf as item (item.id)}
				<a
					href={`/bookshelf/${item.soulerId}`}
					class="group rounded-2xl border border-border/70 bg-background/65 p-3 transition hover:-translate-y-0.5 hover:border-primary/30"
				>
					<div class="grid grid-cols-[4.7rem_1fr] gap-3">
						<div
							class="relative aspect-[3/4] overflow-hidden rounded-lg border border-border/70 bg-muted/30 shadow-[inset_0_0_0_1px_oklch(1_0_0_/_35%)]"
						>
							{#if item.imageUrl}
								<img src={item.imageUrl} alt={item.soulerName} class="h-full w-full object-cover" />
							{:else}
								<div class="grid h-full place-items-center text-xs text-muted-foreground">无图</div>
							{/if}
						</div>
						<div class="min-w-0">
							<h2 class="truncate text-xl leading-8 text-foreground group-hover:text-primary">
								{item.soulerName}
							</h2>
							{#if item.lastSessionTitle}
								<p class="mt-1 line-clamp-2 text-sm leading-6 text-muted-foreground">
									{item.lastSessionTitle}
								</p>
							{:else}
								<p class="mt-1 text-sm leading-6 text-muted-foreground">点击开始阅读章节</p>
							{/if}
						</div>
					</div>
				</a>
			{/each}
		</div>
	{:else}
		<div
			class="rounded-2xl border border-dashed border-border px-5 py-9 text-sm text-muted-foreground"
		>
			还没有共鸣人物。先去移动端生成 Echo 或开启聊天，书架会自动出现。
		</div>
	{/if}
</section>
