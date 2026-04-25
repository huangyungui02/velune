<script lang="ts">
	let {
		href,
		name,
		lang,
		imageUrl = null
	}: {
		href: string;
		name: string;
		lang: string;
		imageUrl?: string | null;
	} = $props();
</script>

<article class="rounded-2xl border border-border/70 bg-background/55 p-3">
	<div class="grid grid-cols-[3.2rem_1fr] gap-3">
		<div class="relative aspect-[3/4] overflow-hidden rounded-lg border border-border/70 bg-muted/30">
			{#if imageUrl}
				<img src={imageUrl} alt={name} class="h-full w-full object-cover" />
			{:else}
				<div class="grid h-full place-items-center text-[10px] text-muted-foreground">无图</div>
			{/if}
		</div>
		<div class="min-w-0 space-y-2">
			<p class="truncate text-base leading-6">{name}</p>
			<p class="text-xs text-muted-foreground">{lang}</p>
			<a
				href={href}
				class="inline-flex h-8 items-center rounded-lg border border-primary/25 bg-primary/10 px-3 text-xs text-primary transition hover:bg-primary/15"
			>
				去编辑
			</a>
		</div>
	</div>
</article>
