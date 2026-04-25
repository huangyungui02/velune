<script lang="ts">
	import { cn } from '$lib/utils';

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

<a
	href={href}
	class={cn('group block rounded-3xl p-1 transition duration-300 hover:-translate-y-1', className)}
>
	<div
		class="relative aspect-[3/4] overflow-hidden rounded-[1.45rem] bg-muted/35 shadow-[0_18px_36px_-24px_oklch(0.24_0.03_57_/_0.55)]"
	>
		{#if imageUrl}
			<img
				src={imageUrl}
				alt={name}
				class="h-full w-full object-cover transition duration-500 group-hover:scale-[1.02]"
			/>
		{:else}
			<div class="grid h-full place-items-center text-xs text-muted-foreground">无图</div>
		{/if}
	</div>

	<div class="mt-3 space-y-1 px-1 text-center">
		<h2 class="truncate text-[1.08rem] leading-7 text-foreground/95 transition group-hover:text-primary">
			{name}
		</h2>
		{#if subtitleText}
			<p class="line-clamp-2 text-sm leading-6 text-muted-foreground">{subtitleText}</p>
		{/if}
		{#if tags.length > 0}
			<div class="mt-2 flex flex-wrap justify-center gap-1.5">
				{#each tags as tag (tag)}
					<span
						class="rounded-full bg-muted/55 px-2 py-0.5 text-[0.68rem] leading-5 tracking-[0.01em] text-muted-foreground"
					>
						{tag}
					</span>
				{/each}
			</div>
		{/if}
	</div>
</a>
