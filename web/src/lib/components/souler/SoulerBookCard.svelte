<script lang="ts">
	import { cn } from '$lib/utils';
	import { Badge } from '$lib/components/ui/badge/index.js';

	let {
		href,
		name,
		imageUrl = null,
		subtitle = '',
		fallbackSubtitle = '',
		tags = [],
		class: className
	}: {
		href: string;
		name: string;
		imageUrl?: string | null;
		subtitle?: string;
		fallbackSubtitle?: string;
		tags?: string[];
		class?: string;
	} = $props();

	const subtitleText = $derived(subtitle.trim() || fallbackSubtitle.trim());
</script>

<a {href} class={cn('group block transition duration-300 hover:-translate-y-1', className)}>
	<div class="gap-0 py-0 transition group-hover:opacity-90">
		<div
			class="relative aspect-[3/4] overflow-hidden rounded-[0.8rem] border border-border/40 bg-muted/20 shadow-sm"
		>
			{#if imageUrl}
				<img
					src={imageUrl}
					alt={name}
					class="h-full w-full object-cover transition duration-700 group-hover:scale-[1.03]"
				/>
			{:else}
				<div class="grid h-full place-items-center text-xs text-muted-foreground/60">无图</div>
			{/if}
		</div>

		<div class="space-y-1.5 px-1 pt-4 pb-2.5 text-center">
			<h2
				class="truncate font-serif text-lg leading-7 text-foreground transition group-hover:text-primary"
			>
				{name}
			</h2>
			{#if subtitleText}
				<p class="line-clamp-2 text-sm leading-6 text-muted-foreground/80">{subtitleText}</p>
			{/if}
			{#if tags.length > 0}
				<div class="mt-2 flex flex-wrap justify-center gap-1.5">
					{#each tags as tag (tag)}
						<Badge
							variant="outline"
							class="border-border/50 bg-transparent px-2 text-[0.65rem] font-normal tracking-widest text-muted-foreground"
						>
							{tag}
						</Badge>
					{/each}
				</div>
			{/if}
		</div>
	</div>
</a>
