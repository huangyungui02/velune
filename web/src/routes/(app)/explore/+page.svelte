<script lang="ts">
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
</script>

<svelte:head>
	<title>Velune · 探索</title>
</svelte:head>

<section class="space-y-6">
	<header class="space-y-2">
		<h1 class="text-3xl leading-tight text-primary">探索</h1>
		<p class="text-sm text-muted-foreground">发现所有 soulers，从一张封面开始。</p>
	</header>

	{#if data.soulers.length > 0}
		<div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
			{#each data.soulers as souler (souler.id)}
				<a
					href={`/bookshelf/${souler.id}`}
					class="group rounded-2xl border border-border/70 bg-background/65 p-3 transition hover:-translate-y-0.5 hover:border-primary/30"
				>
					<div class="grid grid-cols-[4.7rem_1fr] gap-3">
						<div
							class="relative aspect-[3/4] overflow-hidden rounded-lg border border-border/70 bg-muted/30 shadow-[inset_0_0_0_1px_oklch(1_0_0_/_35%)]"
						>
							{#if souler.imageUrl}
								<img src={souler.imageUrl} alt={souler.name} class="h-full w-full object-cover" />
							{:else}
								<div class="grid h-full place-items-center text-xs text-muted-foreground">无图</div>
							{/if}
						</div>
						<div class="min-w-0">
							<h2 class="truncate text-xl leading-8 text-foreground group-hover:text-primary">
								{souler.name}
							</h2>
						</div>
					</div>
				</a>
			{/each}
		</div>
	{:else}
		<div
			class="rounded-2xl border border-dashed border-border px-5 py-9 text-sm text-muted-foreground"
		>
			还没有可探索的人物。
		</div>
	{/if}
</section>
