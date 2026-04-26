<script lang="ts">
	import { Badge } from '$lib/components/ui/badge/index.js';
	import { Button } from '$lib/components/ui/button/index.js';
	import * as Card from '$lib/components/ui/card/index.js';

	let {
		href,
		title,
		subtitle = '',
		lang,
		sectionKey,
		sortOrder,
		itemCount,
		isActive
	}: {
		href: string;
		title: string;
		subtitle?: string;
		lang: string;
		sectionKey: string;
		sortOrder: number;
		itemCount: number;
		isActive: boolean;
	} = $props();
</script>

<Card.Root class="rounded-2xl bg-background/52 py-3 ring-1 ring-border/62">
	<Card.Content class="space-y-3 px-3">
		<div class="space-y-1">
			<p class="line-clamp-1 text-base leading-6">{title}</p>
			{#if subtitle}
				<p class="line-clamp-2 text-xs leading-5 text-muted-foreground">{subtitle}</p>
			{/if}
		</div>

		<div class="flex flex-wrap items-center gap-2">
			<Badge variant="outline" class="text-[0.68rem]">{lang}</Badge>
			<Badge variant="outline" class="text-[0.68rem]">key: {sectionKey}</Badge>
			<Badge variant="outline" class="text-[0.68rem]">#{sortOrder}</Badge>
			<Badge variant="outline" class="text-[0.68rem]">{itemCount} 人</Badge>
			<Badge variant={isActive ? 'secondary' : 'outline'} class="text-[0.68rem]"
				>{isActive ? '启用中' : '已停用'}</Badge
			>
		</div>

		<Button {href} variant="outline" size="sm" class="h-8 rounded-lg text-xs">去编辑</Button>
	</Card.Content>
</Card.Root>
