<script lang="ts">
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
	</header>

	{#if data.soulers.length > 0}
		<div class="grid gap-x-6 gap-y-9 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
			{#each data.soulers as souler (souler.id)}
				<a
					href={`/bookshelf/${souler.id}`}
					class="group block rounded-3xl p-1 transition duration-300 hover:-translate-y-1"
				>
					<div
						class="relative aspect-[3/4] overflow-hidden rounded-[1.45rem] bg-muted/35 shadow-[0_18px_36px_-24px_oklch(0.24_0.03_57_/_0.55)]"
					>
						{#if souler.imageUrl}
							<img
								src={souler.imageUrl}
								alt={souler.name}
								class="h-full w-full object-cover transition duration-500 group-hover:scale-[1.02]"
							/>
						{:else}
							<div class="grid h-full place-items-center text-xs text-muted-foreground">无图</div>
						{/if}
					</div>
					<h2
						class="mt-3 truncate px-1 text-center text-[1.08rem] leading-7 text-foreground/95 transition group-hover:text-primary"
					>
						{souler.name}
					</h2>
				</a>
			{/each}
		</div>
	{:else}
		<div class="rounded-2xl bg-muted/25 px-5 py-9 text-sm text-muted-foreground">
			还没有可发现的人物。
		</div>
	{/if}
</section>
