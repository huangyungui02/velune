<script lang="ts">
	import { afterNavigate, invalidateAll } from '$app/navigation';
	import { page } from '$app/state';
	import Compass from '@lucide/svelte/icons/compass';
	import ChevronDown from '@lucide/svelte/icons/chevron-down';
	import LibraryBig from '@lucide/svelte/icons/library-big';
	import LogOut from '@lucide/svelte/icons/log-out';
	import RotateCw from '@lucide/svelte/icons/rotate-cw';
	import UserRound from '@lucide/svelte/icons/user-round';
	import SoulerSidebarItem from '$lib/components/souler/SoulerSidebarItem.svelte';
	import { pushRoute } from '$lib/stores/navigation-stack';
	import { cn } from '$lib/utils';
	import { Button, buttonVariants } from '$lib/components/ui/button/index.js';
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import type { BookshelfItem } from '$lib/types';
	import type { LayoutProps } from './$types';

	let { data, children }: LayoutProps = $props();
	let bookshelfExpanded = $state(true);
	let bookshelfRefreshing = $state(false);
	let hideMobileNav = $derived(/^\/bookshelf\/[^/]+(?:\/chapter\/[^/]+)?$/.test(page.url.pathname));

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
		<aside class="hidden h-full min-h-0 flex-col border-r border-border/40 pt-10 pb-4 lg:flex">
			<div class="gap-4 px-8">
				<div class="flex items-start justify-between gap-3">
					<div class="min-w-0">
						<p class="font-serif text-2xl leading-none text-primary">Velune</p>
						<p class="mt-2 truncate font-sans text-xs text-muted-foreground">
							{data.user?.email ?? ''}
						</p>
					</div>
					<DropdownMenu.Root>
						<DropdownMenu.Trigger
							class={cn(buttonVariants({ variant: 'ghost', size: 'icon-sm' }), 'rounded-full')}
							aria-label="账号菜单"
						>
							<UserRound class="size-4" />
						</DropdownMenu.Trigger>
						<DropdownMenu.Content align="end" class="w-36">
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

				<nav class="mt-8">
					<Button
						href="/explore"
						variant={isActive('/explore') ? 'default' : 'ghost'}
						size="sm"
						class="h-9 w-full justify-start gap-2 rounded-xl"
						data-sveltekit-preload-data="tap"
						data-sveltekit-preload-code="viewport"
					>
						<Compass class="size-4" />
						发现
					</Button>
				</nav>
			</div>

			<div class="mt-6 px-8">
				<Separator class="opacity-50" />
			</div>

			<div class="scrollbar-soft min-h-0 flex-1 overflow-y-auto overscroll-contain pr-1 pb-4 pl-6">
				<div class="flex items-center justify-between px-2 pt-6 pb-4">
					<button
						type="button"
						class="min-w-0 text-left"
						aria-label="切换书架展开状态"
						aria-expanded={bookshelfExpanded}
						onclick={() => (bookshelfExpanded = !bookshelfExpanded)}
					>
						<span class="font-serif text-xl leading-tight text-primary">书架</span>
					</button>
					<div class="flex items-center gap-0.5">
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
						<Button
							type="button"
							variant="ghost"
							size="icon-sm"
							class="size-8 rounded-full text-muted-foreground/75 hover:text-primary"
							aria-label="切换书架展开状态"
							onclick={() => (bookshelfExpanded = !bookshelfExpanded)}
						>
							<ChevronDown
								class={cn(
									'size-4 transition-transform duration-200',
									bookshelfExpanded ? 'rotate-180' : ''
								)}
							/>
						</Button>
					</div>
				</div>
				{#if bookshelfExpanded}
					<div class="grid gap-2 pb-2">
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
							<p class="px-3 py-4 text-sm text-muted-foreground/60">还没有共鸣人物</p>
						{/if}
					</div>
				{/if}
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
			class="fixed inset-x-4 bottom-4 z-30 grid grid-cols-2 gap-2 rounded-2xl border border-border/50 bg-background/80 p-2 shadow-sm backdrop-blur lg:hidden"
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
		</nav>
	{/if}
</div>
