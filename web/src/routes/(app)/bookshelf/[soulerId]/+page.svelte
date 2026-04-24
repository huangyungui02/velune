<script lang="ts">
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
</script>

<svelte:head>
	<title>Velune · {data.souler.name}</title>
</svelte:head>

<section class="space-y-7">
	<header class="grid gap-5 md:grid-cols-[11rem_1fr]">
		<div
			class="relative aspect-[3/4] overflow-hidden rounded-2xl border border-border/70 bg-muted/30"
		>
			{#if data.souler.imageUrl}
				<img src={data.souler.imageUrl} alt={data.souler.name} class="h-full w-full object-cover" />
			{:else}
				<div class="grid h-full place-items-center text-sm text-muted-foreground">暂无头像</div>
			{/if}
		</div>

		<div class="space-y-3">
			<h1 class="text-4xl leading-tight text-primary">{data.souler.name}</h1>

			{#if data.keywords.length > 0}
				<div class="flex flex-wrap gap-2">
					{#each data.keywords as word (word)}
						<span
							class="rounded-full border border-border/70 bg-background/70 px-3 py-1 text-xs text-muted-foreground"
							>{word}</span
						>
					{/each}
				</div>
			{/if}

			<p class="text-sm leading-7 text-foreground/90">
				{#if data.souler.bio}
					{data.souler.bio}
				{:else}
					暂无简介。
				{/if}
			</p>
		</div>
	</header>

	<section class="space-y-3">
		<h2 class="text-2xl text-primary">章节</h2>

		{#if data.chapters.length}
			<div class="grid gap-3">
				{#each data.chapters as chapter (chapter.id)}
					<a
						href={`/bookshelf/${data.souler.id}/chapter/${chapter.id}`}
						class="rounded-2xl border border-border/70 bg-background/60 px-4 py-3 transition hover:border-primary/25 hover:bg-background/85"
					>
						<p class="text-sm text-muted-foreground">第 {chapter.seq} 章</p>
						<h3 class="text-xl leading-8 text-foreground">{chapter.title}</h3>
						<p class="text-sm leading-6 text-muted-foreground">{chapter.subtitle}</p>
					</a>
				{/each}
			</div>
		{:else}
			<div
				class="rounded-2xl border border-dashed border-border px-4 py-7 text-sm text-muted-foreground"
			>
				当前人物还没有章节。
			</div>
		{/if}
	</section>
</section>
