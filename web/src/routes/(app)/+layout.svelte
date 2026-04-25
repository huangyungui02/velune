<script lang="ts">
	import { page } from '$app/state';
	import SoulerSidebarItem from '$lib/components/souler/SoulerSidebarItem.svelte';
	import type { LayoutProps } from './$types';

	let { data, children }: LayoutProps = $props();

	function navClass(href: string) {
		const active =
			page.url.pathname === href ||
			(href !== '/explore' && page.url.pathname.startsWith(`${href}/`));
		return active
			? 'bg-primary text-primary-foreground border-primary/20'
			: 'bg-card/50 text-foreground border-border/70 hover:bg-accent/40';
	}
</script>

<div class="h-dvh w-full overflow-hidden px-4 py-4 md:px-6 md:py-5 lg:px-8 lg:py-6">
	<div class="mx-auto grid h-full w-full max-w-7xl gap-5 lg:grid-cols-[17rem_minmax(0,1fr)]">
		<aside
			class="hidden h-full overflow-hidden rounded-3xl border border-border/70 bg-card/80 lg:flex lg:flex-col"
		>
			<div class="space-y-5 px-4 pt-4">
				<div class="flex items-start justify-between gap-3">
					<div class="min-w-0">
						<p class="font-hand text-3xl leading-none text-primary">Velune</p>
						<p class="mt-2 truncate text-xs text-muted-foreground">{data.user?.email ?? ''}</p>
					</div>
					<details class="relative">
						<summary
							class="flex h-8 w-8 cursor-pointer list-none items-center justify-center rounded-full border border-border/80 bg-card/85 text-muted-foreground transition hover:bg-accent/50 hover:text-foreground [&::-webkit-details-marker]:hidden"
							aria-label="账号菜单"
						>
							<svg
								viewBox="0 0 24 24"
								class="h-4 w-4"
								fill="none"
								stroke="currentColor"
								stroke-width="1.8"
								stroke-linecap="round"
								stroke-linejoin="round"
							>
								<circle cx="12" cy="7" r="3.2"></circle>
								<path d="M5.5 19.2c1.4-3 3.8-4.5 6.5-4.5s5.1 1.5 6.5 4.5"></path>
							</svg>
						</summary>
						<div
							class="absolute right-0 top-10 z-20 w-32 rounded-xl border border-border/80 bg-popover/95 p-1.5 shadow-sm"
						>
							<form method="POST" action="/logout">
								<button
									type="submit"
									class="w-full rounded-lg px-2 py-1.5 text-left text-xs text-destructive transition hover:bg-destructive/10"
								>
									退出登录
								</button>
							</form>
						</div>
					</details>
				</div>

				<nav class="grid gap-2">
					<a
						class={`rounded-2xl border px-3 py-2 text-sm transition ${navClass('/explore')}`}
						href="/explore">发现</a
					>
				</nav>
			</div>

			<div class="scrollbar-soft mt-4 min-h-0 flex-1 overflow-y-auto px-4 pb-4">
				<p class="pb-3 text-xs tracking-[0.18em] text-muted-foreground">RESONANCES</p>
				<div class="grid gap-2">
					{#if data.bookshelf?.length}
						{#each data.bookshelf as item (item.id)}
							<SoulerSidebarItem
								href={`/bookshelf/${item.soulerId}`}
								name={item.soulerName}
								imageUrl={item.imageUrl}
								lastSessionTitle={item.lastSessionTitle}
								active={page.url.pathname.startsWith(`/bookshelf/${item.soulerId}`)}
							/>
						{/each}
					{:else}
						<p class="rounded-2xl border border-dashed border-border px-3 py-4 text-xs text-muted-foreground">
							还没有共鸣人物
						</p>
					{/if}
				</div>
			</div>
		</aside>

		<main
			class="scrollbar-soft h-full overflow-y-auto rounded-3xl border border-border/70 bg-card/70 p-5 pb-24 md:p-7 md:pb-24 lg:pb-7"
		>
			{@render children()}
		</main>
	</div>

	<nav
		class="fixed inset-x-4 bottom-4 z-30 grid grid-cols-2 gap-2 rounded-2xl border border-border/80 bg-card/95 p-2 shadow-sm backdrop-blur lg:hidden"
	>
		<a
			class={`rounded-xl px-3 py-2 text-center text-sm transition ${navClass('/explore')}`}
			href="/explore">发现</a
		>
		<a
			class={`rounded-xl px-3 py-2 text-center text-sm transition ${navClass('/bookshelf')}`}
			href="/bookshelf">书架</a
		>
	</nav>
</div>
