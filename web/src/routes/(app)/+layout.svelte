<script lang="ts">
	import { page } from '$app/state';
	import Compass from '@lucide/svelte/icons/compass';
	import LibraryBig from '@lucide/svelte/icons/library-big';
	import LogOut from '@lucide/svelte/icons/log-out';
	import UserRound from '@lucide/svelte/icons/user-round';
	import SoulerSidebarItem from '$lib/components/souler/SoulerSidebarItem.svelte';
	import { cn } from '$lib/utils';
	import { Button, buttonVariants } from '$lib/components/ui/button/index.js';
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import type { BookshelfItem } from '$lib/types';
	import type { LayoutProps } from './$types';

	let { data, children }: LayoutProps = $props();

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
</script>

<div class="h-dvh w-full overflow-hidden">
	<div class="mx-auto grid h-full min-h-0 w-full max-w-7xl lg:grid-cols-[16rem_minmax(0,1fr)]">
		<aside class="hidden h-full min-h-0 flex-col border-r border-border/40 pb-4 pt-10 lg:flex">
			<div class="px-8 gap-4">
				<div class="flex items-start justify-between gap-3">
					<div class="min-w-0">
						<p class="font-hand text-4xl leading-none text-primary">Velune</p>
						<p class="mt-2 truncate font-sans text-xs text-muted-foreground">{data.user?.email ?? ''}</p>
					</div>
					<DropdownMenu.Root>
						<DropdownMenu.Trigger
							class={cn(
								buttonVariants({ variant: 'ghost', size: 'icon-sm' }),
								'rounded-full'
							)}
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
					>
						<Compass class="size-4" />
						发现
					</Button>
				</nav>
			</div>

			<div class="px-8 mt-6">
				<Separator class="opacity-50" />
			</div>

			<div class="min-h-0 flex-1 overflow-y-auto overscroll-contain scrollbar-soft pl-6 pr-1 pb-4">
				<p class="pt-6 pb-4 px-2 text-xs font-sans tracking-[0.2em] text-muted-foreground/70">RESONANCES</p>
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
						<p class="px-3 py-4 text-sm text-muted-foreground/60">
							还没有共鸣人物
						</p>
					{/if}
				</div>
			</div>
		</aside>

		<main class="relative h-full min-h-0 min-w-0">
			<div class="h-full min-h-0 w-full overflow-y-auto overscroll-contain scrollbar-soft">
				<div class="p-6 md:p-10 lg:p-12 pb-32">
					{@render children()}
				</div>
			</div>
		</main>
	</div>

	<nav
		class="fixed inset-x-4 bottom-4 z-30 grid grid-cols-2 gap-2 rounded-2xl border border-border/50 bg-background/80 p-2 shadow-sm backdrop-blur lg:hidden"
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
</div>
