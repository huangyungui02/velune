<script lang="ts">
	import SoulerBookCard from '$lib/components/souler/SoulerBookCard.svelte';
	import type { ExploreSection } from '$lib/types';

	let {
		sections,
		loading,
		error
	}: {
		sections: ExploreSection[] | null;
		loading: boolean;
		error: string;
	} = $props();
</script>

{#if sections && sections.length > 0}
	<div class="space-y-10">
		{#each sections as section (section.id)}
			<section class="space-y-4">
				<div class="px-1">
					<h2 class="font-serif text-xl leading-tight text-primary md:text-2xl">
						{section.title}
					</h2>
					{#if section.subtitle}
						<p class="mt-1 text-sm text-muted-foreground/80">{section.subtitle}</p>
					{/if}
				</div>

				<div class="scrollbar-soft -mx-1 overflow-x-auto overscroll-x-contain pb-3 pl-1">
					<div
						class="grid min-w-max auto-cols-[minmax(7.25rem,7.75rem)] grid-flow-col gap-3 pr-4 md:auto-cols-[minmax(10rem,11.5rem)] md:gap-4"
					>
						{#each section.soulers as souler (souler.id)}
							<SoulerBookCard
								href={`/bookshelf/${souler.id}`}
								name={souler.name}
								imageUrl={souler.imageUrl}
							/>
						{/each}
					</div>
				</div>
			</section>
		{/each}
	</div>
{:else if loading}
	<div class="px-2 py-8 text-sm text-muted-foreground/70">正在加载精选...</div>
{:else if error}
	<p class="text-sm text-destructive/90">{error}</p>
{:else}
	<div class="px-2 py-8 text-sm text-muted-foreground/70">还没有可展示的精选分组。</div>
{/if}
