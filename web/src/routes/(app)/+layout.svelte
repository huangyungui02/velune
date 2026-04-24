<script lang="ts">
	import { page } from '$app/state';
	import type { LayoutProps } from './$types';

	let { data, children }: LayoutProps = $props();

	function navClass(href: string) {
		const active = page.url.pathname === href;
		return active
			? 'bg-primary text-primary-foreground border-primary/20'
			: 'bg-card/50 text-foreground border-border/70 hover:bg-accent/40';
	}

	function bookClass(soulerId: string) {
		const active = page.url.pathname.startsWith(`/bookshelf/${soulerId}`);
		return active
			? 'border-primary/35 bg-primary/10'
			: 'border-border/70 bg-card/60 hover:bg-card/95';
	}
</script>

<div class="mx-auto w-full max-w-7xl px-4 py-5 md:px-6 lg:px-8">
	<div class="grid min-h-[calc(100dvh-2.5rem)] gap-5 lg:grid-cols-[18rem_1fr]">
		<aside class="hidden rounded-3xl border border-border/70 bg-card/80 p-4 lg:flex lg:flex-col">
			<div class="px-2 pb-4">
				<p class="font-hand text-3xl leading-none text-primary">Velune</p>
				<p class="mt-2 text-xs text-muted-foreground">{data.user?.email ?? ''}</p>
			</div>

			<nav class="grid gap-2">
				<a
					class={`rounded-2xl border px-3 py-2 text-sm transition ${navClass('/explore')}`}
					href="/explore">发现</a
				>
				<a
					class={`rounded-2xl border px-3 py-2 text-sm transition ${navClass('/bookshelf')}`}
					href="/bookshelf">书架</a
				>
				<a
					class={`rounded-2xl border px-3 py-2 text-sm transition ${navClass('/settings')}`}
					href="/settings">设置</a
				>
			</nav>

			<div class="mt-5 min-h-0 flex-1 overflow-y-auto">
				<p class="px-2 pb-3 text-xs tracking-[0.18em] text-muted-foreground">BOOKSHELF</p>
				<div class="grid gap-2">
					{#if data.bookshelf?.length}
						{#each data.bookshelf as item (item.id)}
							<a
								href={`/bookshelf/${item.soulerId}`}
								class={`grid grid-cols-[2.3rem_1fr] gap-2 rounded-2xl border p-2 transition ${bookClass(item.soulerId)}`}
							>
								<div
									class="relative aspect-[3/4] overflow-hidden rounded-lg border border-border/70 bg-muted/40"
								>
									{#if item.imageUrl}
										<img
											src={item.imageUrl}
											alt={item.soulerName}
											class="h-full w-full object-cover"
										/>
									{:else}
										<div class="grid h-full place-items-center text-xs text-muted-foreground">
											无图
										</div>
									{/if}
								</div>
								<div class="min-w-0">
									<p class="truncate text-sm leading-6">{item.soulerName}</p>
									{#if item.lastSessionTitle}
										<p class="line-clamp-2 text-xs leading-5 text-muted-foreground">
											{item.lastSessionTitle}
										</p>
									{:else}
										<p class="text-xs leading-5 text-muted-foreground">尚未开始章节</p>
									{/if}
								</div>
							</a>
						{/each}
					{:else}
						<p
							class="rounded-2xl border border-dashed border-border px-3 py-4 text-xs text-muted-foreground"
						>
							还没有共鸣人物
						</p>
					{/if}
				</div>
			</div>
		</aside>

		<main class="rounded-3xl border border-border/70 bg-card/70 p-5 md:p-7">
			{@render children()}
		</main>
	</div>

	<nav
		class="fixed inset-x-4 bottom-4 z-30 grid grid-cols-3 gap-2 rounded-2xl border border-border/80 bg-card/95 p-2 shadow-sm backdrop-blur lg:hidden"
	>
		<a
			class={`rounded-xl px-3 py-2 text-center text-sm transition ${navClass('/explore')}`}
			href="/explore">发现</a
		>
		<a
			class={`rounded-xl px-3 py-2 text-center text-sm transition ${navClass('/bookshelf')}`}
			href="/bookshelf">书架</a
		>
		<a
			class={`rounded-xl px-3 py-2 text-center text-sm transition ${navClass('/settings')}`}
			href="/settings">设置</a
		>
	</nav>
</div>
