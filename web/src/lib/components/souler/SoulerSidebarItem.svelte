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

<a {href} class="group block">
	<div
		class={cn(
			'flex items-center gap-4 rounded-2xl px-3.5 py-3 transition',
			active ? 'bg-primary/10 text-primary' : 'text-foreground hover:bg-primary/5'
		)}
	>
		<div class="relative h-16 w-12 shrink-0 overflow-hidden rounded-lg bg-muted/40">
			{#if imageUrl}
				<img src={imageUrl} alt={name} class="h-full w-full object-cover" />
			{:else}
				<div class="grid h-full place-items-center text-[0.62rem] text-muted-foreground/60">
					无图
				</div>
			{/if}
		</div>
		<div class="min-w-0 flex-1">
			<p class="truncate font-serif text-lg leading-6">{name}</p>
			{#if lastSessionTitle.trim()}
				<p class="mt-1 truncate text-sm leading-6 text-muted-foreground/80">{lastSessionTitle}</p>
			{:else}
				<p class="mt-1 text-sm leading-6 text-muted-foreground/60">尚未开始</p>
			{/if}
		</div>
	</div>
</a>
