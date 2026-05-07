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
			buttonVariants({ variant: 'ghost', size: 'icon-sm' }),
			'size-9 rounded-full text-muted-foreground/80 hover:text-primary'
		)}
		aria-label="分享对话"
	>
		<Share2 class="size-4" />
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
