<script lang="ts">
	import { Badge } from '$lib/components/ui/badge/index.js';
	import { Button } from '$lib/components/ui/button/index.js';
	import * as Card from '$lib/components/ui/card/index.js';

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

<Card.Root class="gap-0 rounded-2xl bg-background/52 py-3 ring-1 ring-border/62">
	<Card.Content class="grid grid-cols-[3.2rem_1fr] items-start gap-3 px-3">
		<div class="relative aspect-[3/4] overflow-hidden rounded-lg bg-muted/30 ring-1 ring-border/65">
			{#if imageUrl}
				<img src={imageUrl} alt={name} class="h-full w-full object-cover" />
			{:else}
				<div class="grid h-full place-items-center text-[10px] text-muted-foreground">无图</div>
			{/if}
		</div>
		<div class="min-w-0 space-y-2.5">
			<p class="truncate text-base leading-6">{name}</p>
			<Badge variant="outline" class="text-[0.68rem]">{lang}</Badge>
			<Button {href} variant="outline" size="sm" class="h-8 rounded-lg text-xs">去编辑</Button>
		</div>
	</Card.Content>
</Card.Root>
