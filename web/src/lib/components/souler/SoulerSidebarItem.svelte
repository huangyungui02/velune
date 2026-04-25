<script lang="ts">
	import { cn } from '$lib/utils';

	let {
		href,
		name,
		imageUrl = null,
		lastSessionTitle = '',
		active = false
	}: {
		href: string;
		name: string;
		imageUrl?: string | null;
		lastSessionTitle?: string;
		active?: boolean;
	} = $props();
</script>

<a
	href={href}
	class={cn(
		'grid grid-cols-[2.3rem_1fr] gap-2 rounded-2xl border p-2 transition',
		active ? 'border-primary/35 bg-primary/10' : 'border-border/70 bg-card/60 hover:bg-card/95'
	)}
>
	<div class="relative aspect-[3/4] overflow-hidden rounded-lg border border-border/70 bg-muted/40">
		{#if imageUrl}
			<img src={imageUrl} alt={name} class="h-full w-full object-cover" />
		{:else}
			<div class="grid h-full place-items-center text-xs text-muted-foreground">无图</div>
		{/if}
	</div>
	<div class="min-w-0">
		<p class="truncate text-sm leading-6">{name}</p>
		{#if lastSessionTitle.trim()}
			<p class="line-clamp-2 text-xs leading-5 text-muted-foreground">{lastSessionTitle}</p>
		{:else}
			<p class="text-xs leading-5 text-muted-foreground">尚未开始章节</p>
		{/if}
	</div>
</a>
