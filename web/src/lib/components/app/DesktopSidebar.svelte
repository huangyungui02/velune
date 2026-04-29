<script lang="ts">
	import { page } from '$app/state';
	import Compass from '@lucide/svelte/icons/compass';
	import LogOut from '@lucide/svelte/icons/log-out';
	import MessageCircle from '@lucide/svelte/icons/message-circle';
	import SidebarBookshelfSection from '$lib/components/app/SidebarBookshelfSection.svelte';
	import { Button, buttonVariants } from '$lib/components/ui/button/index.js';
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu/index.js';
	import { cn } from '$lib/utils';

	let { userEmail }: { userEmail: string } = $props();
	const userInitial = $derived((userEmail.trim().charAt(0) || 'V').toUpperCase());
	const developerContactUrl = 'https://xhslink.com/m/6RghZ8ot2N0';

	function isActive(href: string) {
		return (
			page.url.pathname === href ||
			(href !== '/explore' && page.url.pathname.startsWith(`${href}/`))
		);
	}
</script>

<aside class="hidden h-full min-h-0 flex-col border-r border-border/40 pt-10 lg:flex">
	<div class="px-6 pb-4">
		<p class="font-serif text-2xl leading-none text-primary">Velune</p>
	</div>

	<div class="scrollbar-soft min-h-0 flex-1 overflow-y-auto overscroll-contain pr-1">
		<div class="space-y-3 px-5 pt-2 pb-4">
			<Button
				href="/explore"
				variant={isActive('/explore') ? 'default' : 'ghost'}
				size="sm"
				class="h-10 w-full justify-start gap-2 rounded-xl px-3 transition-transform active:scale-[0.98]"
				data-sveltekit-preload-data="tap"
				data-sveltekit-preload-code="viewport"
			>
				<Compass class="size-4" />
				发现
			</Button>

			<SidebarBookshelfSection />
		</div>
	</div>

	<div class="border-t border-border/40 px-5 pt-4 pb-4">
		<DropdownMenu.Root>
			<DropdownMenu.Trigger
				class={cn(
					buttonVariants({ variant: 'ghost', size: 'sm' }),
					'h-11 w-full justify-start rounded-xl px-2.5 transition-transform active:scale-[0.98]'
				)}
				aria-label="账号菜单"
			>
				<div
					class="grid size-7 shrink-0 place-items-center rounded-full bg-primary/10 text-xs font-medium text-primary"
				>
					{userInitial}
				</div>
				<div class="min-w-0 text-left">
					<p class="truncate text-xs text-muted-foreground">{userEmail}</p>
				</div>
			</DropdownMenu.Trigger>
			<DropdownMenu.Content align="end" class="w-40">
				<Button
					href={developerContactUrl}
					target="_blank"
					rel="noreferrer"
					variant="ghost"
					size="sm"
					class="mb-1 h-8 w-full justify-start gap-2"
				>
					<MessageCircle class="size-3.5" />
					联系开发者
				</Button>
				<form method="POST" action="/logout">
					<Button
						type="submit"
						variant="ghost"
						size="sm"
						class="h-8 w-full justify-start gap-2 text-destructive hover:bg-destructive/10 hover:text-destructive"
					>
						<LogOut class="size-3.5" />
						退出登录
					</Button>
				</form>
			</DropdownMenu.Content>
		</DropdownMenu.Root>
	</div>
</aside>
