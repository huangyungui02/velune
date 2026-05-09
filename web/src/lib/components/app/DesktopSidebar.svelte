<script lang="ts">
	import { page } from '$app/state';
	import Compass from '@lucide/svelte/icons/compass';
	import AccountPanel from '$lib/components/app/AccountPanel.svelte';
	import SidebarBookshelfSection from '$lib/components/app/SidebarBookshelfSection.svelte';
	import { Button } from '$lib/components/ui/button/index.js';
	import * as Dialog from '$lib/components/ui/dialog/index.js';

	let { userEmail }: { userEmail: string } = $props();
	const userInitial = $derived((userEmail.trim().charAt(0) || 'V').toUpperCase());

	function isActive(href: string) {
		return page.url.pathname === href || page.url.pathname.startsWith(`${href}/`);
	}
</script>

<aside class="hidden h-full min-h-0 flex-col border-r border-border/40 pt-10 lg:flex">
	<div class="px-6 pb-4">
		<p class="font-serif text-2xl leading-none text-primary">Velune Folio</p>
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
		<Dialog.Root>
			<Dialog.Trigger
				class="inline-flex h-11 w-full items-center justify-start gap-1 rounded-xl border border-transparent bg-clip-padding px-2.5 text-sm font-medium whitespace-nowrap transition-all outline-none select-none hover:bg-muted hover:text-foreground focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 active:scale-[0.98] aria-expanded:bg-muted aria-expanded:text-foreground"
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
			</Dialog.Trigger>

			<Dialog.Content class="max-w-md">
				<Dialog.Header>
					<Dialog.Title class="text-primary">我的</Dialog.Title>
				</Dialog.Header>
				<AccountPanel email={userEmail} logoutAction="/logout" />
			</Dialog.Content>
		</Dialog.Root>
	</div>
</aside>
