<script lang="ts">
	import Check from '@lucide/svelte/icons/check';
	import Copy from '@lucide/svelte/icons/copy';
	import ImageDown from '@lucide/svelte/icons/image-down';
	import Share2 from '@lucide/svelte/icons/share-2';
	import { buttonVariants } from '$lib/components/ui/button/index.js';
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu/index.js';
	import { cn } from '$lib/utils.js';

	let {
		disabled,
		copied,
		onCopy,
		onExportImage
	}: {
		disabled: boolean;
		copied: boolean;
		onCopy: () => void;
		onExportImage: () => void;
	} = $props();
</script>

<DropdownMenu.Root>
	<DropdownMenu.Trigger
		class={cn(
			// Mobile (original ghost icon-sm style)
			'flex size-9 items-center justify-center rounded-full text-muted-foreground/80 hover:bg-accent hover:text-accent-foreground',
			// Desktop (liquid glass style)
			'md:size-10 md:bg-background/50 md:backdrop-blur-xl md:border md:border-foreground/5 md:shadow-[0_2px_10px_-3px_rgba(0,0,0,0.1)] md:transition-all md:duration-300 md:hover:scale-105 md:hover:bg-background/70 md:focus-visible:outline-none md:focus-visible:ring-2 md:focus-visible:ring-ring md:active:scale-95',
			'md:data-[state=open]:bg-background/70 md:data-[state=open]:scale-105'
		)}
		aria-label="分享对话"
	>
		<Share2 class="size-5 text-foreground/70 transition-transform" strokeWidth={2} />
	</DropdownMenu.Trigger>
	<DropdownMenu.Content align="end" class="w-40">
		<DropdownMenu.Item {disabled} onclick={onCopy}>
			{#if copied}
				<Check class="size-4" />
				已复制
			{:else}
				<Copy class="size-4" />
				复制对话内容
			{/if}
		</DropdownMenu.Item>
		<DropdownMenu.Item {disabled} onclick={onExportImage}>
			<ImageDown class="size-4" />
			导出为图片
		</DropdownMenu.Item>
	</DropdownMenu.Content>
</DropdownMenu.Root>
