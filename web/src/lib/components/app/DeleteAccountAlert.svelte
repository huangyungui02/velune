<script lang="ts">
	import { AlertDialog as AlertDialogPrimitive } from 'bits-ui';
	import { Button, buttonVariants } from '$lib/components/ui/button/index.js';
	import { cn } from '$lib/utils';

	let {
		triggerClass,
		triggerLabel = '注销账号',
		triggerTitle = '注销账号',
		children
	}: {
		triggerClass?: string;
		triggerLabel?: string;
		triggerTitle?: string;
		children?: import('svelte').Snippet;
	} = $props();
</script>

<AlertDialogPrimitive.Root>
	<AlertDialogPrimitive.Trigger
		class={cn(buttonVariants({ variant: 'ghost', size: 'sm' }), triggerClass)}
		aria-label={triggerLabel}
		title={triggerTitle}
	>
		{@render children?.()}
	</AlertDialogPrimitive.Trigger>

	<AlertDialogPrimitive.Portal>
		<AlertDialogPrimitive.Overlay
			class="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm duration-150 data-open:animate-in data-open:fade-in-0 data-closed:animate-out data-closed:fade-out-0"
		/>
		<AlertDialogPrimitive.Content
			class="fixed top-1/2 left-1/2 z-50 grid w-[calc(100%-2rem)] max-w-sm -translate-x-1/2 -translate-y-1/2 gap-5 rounded-2xl border border-border bg-background p-5 text-foreground shadow-lg duration-150 outline-none data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95"
		>
			<div class="space-y-2">
				<AlertDialogPrimitive.Title class="text-base font-medium">
					确认注销账号？
				</AlertDialogPrimitive.Title>
				<AlertDialogPrimitive.Description class="text-sm leading-6 text-muted-foreground">
					账号注销后，当前账号与相关数据将被删除。这个操作无法撤销。
				</AlertDialogPrimitive.Description>
			</div>

			<div class="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
				<AlertDialogPrimitive.Cancel
					class={cn(buttonVariants({ variant: 'outline', size: 'sm' }), 'w-full sm:w-auto')}
				>
					取消
				</AlertDialogPrimitive.Cancel>
				<form method="POST" action="/account/delete" class="w-full sm:w-auto">
					<Button type="submit" variant="destructive" size="sm" class="w-full sm:w-auto">
						确认注销
					</Button>
				</form>
			</div>
		</AlertDialogPrimitive.Content>
	</AlertDialogPrimitive.Portal>
</AlertDialogPrimitive.Root>
