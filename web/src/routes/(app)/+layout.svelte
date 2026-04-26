<script lang="ts">
	import { afterNavigate, invalidateAll } from '$app/navigation';
	import { page } from '$app/state';
	import Compass from '@lucide/svelte/icons/compass';
	import ChevronDown from '@lucide/svelte/icons/chevron-down';
	import LibraryBig from '@lucide/svelte/icons/library-big';
	import LogOut from '@lucide/svelte/icons/log-out';
	import MessageCircle from '@lucide/svelte/icons/message-circle';
	import RotateCw from '@lucide/svelte/icons/rotate-cw';
	import UserRound from '@lucide/svelte/icons/user-round';
	import SoulerSidebarItem from '$lib/components/souler/SoulerSidebarItem.svelte';
	import { pushRoute } from '$lib/stores/navigation-stack';
	import { cn } from '$lib/utils';
	import { Button, buttonVariants } from '$lib/components/ui/button/index.js';
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu/index.js';
	import type { BookshelfItem } from '$lib/types';
	import type { LayoutProps } from './$types';

	let { data, children }: LayoutProps = $props();
	let bookshelfExpanded = $state(true);
	let bookshelfRefreshing = $state(false);
	let hideMobileNav = $derived(/^\/bookshelf\/[^/]+(?:\/chapter\/[^/]+)?$/.test(page.url.pathname));
	const userEmail = $derived(data.user?.email ?? '');
	const userInitial = $derived((userEmail.trim().charAt(0) || 'V').toUpperCase());
	const developerContactUrl = 'https://xhslink.com/m/6RghZ8ot2N0';

	function isActive(href: string) {
		return (
			page.url.pathname === href ||
			(href !== '/explore' && page.url.pathname.startsWith(`${href}/`))
		);
	}

	function getResonanceHref(item: BookshelfItem) {
		if (!item.lastSessionId || !item.lastChapterId) {
			return `/bookshelf/${item.soulerId}`;
		}
		const query = new URLSearchParams({ session: item.lastSessionId });
		return `/bookshelf/${item.soulerId}/chapter/${item.lastChapterId}?${query.toString()}`;
	}

	async function refreshBookshelf() {
		if (bookshelfRefreshing) {
			return;
		}
		bookshelfRefreshing = true;
		try {
			await invalidateAll();
		} finally {
			bookshelfRefreshing = false;
		}
	}

	pushRoute(page.url);
	afterNavigate(({ to }) => {
		if (to?.url) {
			pushRoute(to.url);
		}
	});
</script>

<div class="h-dvh w-full overflow-hidden">
	<div class="mx-auto grid h-full min-h-0 w-full max-w-7xl lg:grid-cols-[16rem_minmax(0,1fr)]">
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
						class="h-10 w-full justify-start gap-2 rounded-xl px-3"
						data-sveltekit-preload-data="tap"
						data-sveltekit-preload-code="viewport"
					>
						<Compass class="size-4" />
						发现
					</Button>

					<div class="space-y-2">
						<div class="flex items-center gap-1.5">
							<Button
								type="button"
								variant={isActive('/bookshelf') ? 'default' : 'ghost'}
								size="sm"
								class="h-10 flex-1 justify-start gap-2 rounded-xl px-3"
								aria-label="切换书架展开状态"
								aria-expanded={bookshelfExpanded}
								onclick={() => (bookshelfExpanded = !bookshelfExpanded)}
							>
								<LibraryBig class="size-4" />
								<span>书架</span>
								<ChevronDown
									class={cn(
										'ml-auto size-4 transition-transform duration-200',
										bookshelfExpanded ? 'rotate-180' : ''
									)}
								/>
							</Button>
							<Button
								type="button"
								variant="ghost"
								size="icon-sm"
								class="size-8 rounded-full text-muted-foreground/75 hover:text-primary"
								onclick={refreshBookshelf}
								disabled={bookshelfRefreshing}
								aria-label="刷新书架"
							>
								<RotateCw class={cn('size-3.5', bookshelfRefreshing && 'animate-spin')} />
							</Button>
						</div>

						{#if bookshelfExpanded}
							<div class="grid gap-2 pt-1">
								{#if data.bookshelf?.length}
									{#each data.bookshelf as item (item.id)}
										<SoulerSidebarItem
											href={getResonanceHref(item)}
											name={item.soulerName}
											imageUrl={item.imageUrl}
											lastSessionTitle={item.lastSessionTitle}
											active={page.url.pathname.startsWith(`/bookshelf/${item.soulerId}`)}
										/>
									{/each}
								{:else}
									<p class="px-3 py-4 text-sm text-muted-foreground/60">书架为空</p>
								{/if}
							</div>
						{/if}
					</div>
				</div>
			</div>

			<div class="border-t border-border/40 px-5 pt-4 pb-4">
				<DropdownMenu.Root>
					<DropdownMenu.Trigger
						class={cn(
							buttonVariants({ variant: 'ghost', size: 'sm' }),
							'h-11 w-full justify-start rounded-xl px-2.5'
						)}
						aria-label="账号菜单"
					>
						<div class="grid size-7 shrink-0 place-items-center rounded-full bg-primary/10 text-xs font-medium text-primary">
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

		<main class="relative h-full min-h-0 min-w-0">
			<div
				class="scrollbar-soft h-full min-h-0 w-full overflow-y-auto overscroll-contain"
				data-main-scroll-container
			>
				<div class="p-6 pb-32 md:p-10 lg:p-12">
					{@render children()}
				</div>
			</div>
		</main>
	</div>

	{#if !hideMobileNav}
		<nav
			class="fixed inset-x-4 bottom-4 z-30 grid grid-cols-3 gap-2 rounded-2xl border border-border/50 bg-background/80 p-2 shadow-sm backdrop-blur lg:hidden"
			data-sveltekit-preload-data="tap"
			data-sveltekit-preload-code="viewport"
		>
			<Button
				href="/explore"
				variant={isActive('/explore') ? 'default' : 'ghost'}
				size="sm"
				class="h-10 gap-2 rounded-xl"
			>
				<Compass class="size-4" />
				发现
			</Button>
			<Button
				href="/bookshelf"
				variant={isActive('/bookshelf') ? 'default' : 'ghost'}
				size="sm"
				class="h-10 gap-2 rounded-xl"
			>
				<LibraryBig class="size-4" />
				书架
			</Button>
			<Button
				href="/settings"
				variant={isActive('/settings') ? 'default' : 'ghost'}
				size="sm"
				class="h-10 gap-2 rounded-xl"
			>
				<UserRound class="size-4" />
				我的
			</Button>
		</nav>
	{/if}
</div>
