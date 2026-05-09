<script lang="ts">
	import { resolve } from '$app/paths';
	import Clock from '@lucide/svelte/icons/clock';
	import UserRound from '@lucide/svelte/icons/user-round';
	import { onMount } from 'svelte';
	import { Button } from '$lib/components/ui/button/index.js';
	import PageTopToolbar from '$lib/components/ui/page-top-toolbar.svelte';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	function scrollMainContainerToTop() {
		if (typeof document === 'undefined') {
			return;
		}
		const container = document.querySelector<HTMLElement>('[data-main-scroll-container]');
		container?.scrollTo({ top: 0, behavior: 'auto' });
	}

	function formatChapterNumber(seq: number) {
		const value = Number(seq);
		if (!Number.isFinite(value) || value <= 0) {
			return '00';
		}
		return String(Math.trunc(value)).padStart(2, '0');
	}

	function formatHistoryDate(value: string) {
		const date = new Date(value);
		if (Number.isNaN(date.getTime())) {
			return '时间未知';
		}

		return new Intl.DateTimeFormat('zh-CN', {
			year: 'numeric',
			month: 'long',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		}).format(date);
	}

	onMount(() => {
		scrollMainContainerToTop();
	});

</script>

<svelte:head>
	<title>Velune Folio · {data.souler.name}</title>
</svelte:head>

<section class="space-y-6 pt-[calc(env(safe-area-inset-top)+3.4rem)] md:pt-0">
	<PageTopToolbar title={data.souler.name} backHref="/bookshelf" class="md:hidden">
		<Button
			href={resolve(`/bookshelf/${data.souler.id}/profile`)}
			variant="ghost"
			size="icon-sm"
			class="size-9 rounded-full text-muted-foreground/80 transition-colors hover:bg-accent hover:text-accent-foreground"
			aria-label="人物简介"
		>
			<UserRound class="size-5 text-foreground/70" strokeWidth={2} />
		</Button>
	</PageTopToolbar>

	<header class="hidden md:flex md:items-center md:justify-between">
		<h1 class="font-serif text-2xl leading-tight text-primary">{data.souler.name}</h1>
		<a
			href={resolve(`/bookshelf/${data.souler.id}/profile`)}
			class="group flex items-center gap-1.5 text-[0.8rem] text-muted-foreground/50 transition-colors hover:text-primary"
			aria-label="查看资料"
		>
			<span class="tracking-[0.15em]">查看资料</span>
			<UserRound
				class="size-3.5 transition-transform group-hover:translate-x-0.5"
				strokeWidth={1.5}
			/>
		</a>
	</header>

	<section>
		{#if data.chapters.length}
			<div class="divide-y divide-border/45">
				{#each data.chapters as chapter (chapter.id)}
					<a
						href={resolve(`/bookshelf/${data.souler.id}/chapter/${chapter.id}`)}
						class="group flex min-h-24 flex-col gap-3 px-1 py-5 transition-colors hover:bg-muted/18 md:flex-row md:items-center md:justify-between md:gap-8 md:px-3"
					>
						<div class="min-w-0">
							<p class="mb-2 text-[0.72rem] tracking-[0.24em] text-muted-foreground/70">
								{formatChapterNumber(chapter.seq)}
							</p>
							<h3
								class="text-xl leading-7 text-foreground transition-colors group-hover:text-primary"
							>
								{chapter.title}
							</h3>
							{#if chapter.subtitle}
								<p class="mt-2 max-w-2xl text-sm leading-6 text-muted-foreground">
									{chapter.subtitle}
								</p>
							{/if}
						</div>

						{#if chapter.latestHistory}
							<div
								class="flex shrink-0 flex-wrap items-center gap-x-4 gap-y-1.5 font-sans text-sm text-muted-foreground/78 md:w-[18rem] md:justify-end"
								aria-label={`最近记录：${formatHistoryDate(chapter.latestHistory.updatedAt)}`}
							>
								<span class="flex items-center gap-1.5 tabular-nums">
									<Clock class="size-4 stroke-[1.8]" />
									{formatHistoryDate(chapter.latestHistory.updatedAt)}
								</span>
							</div>
						{/if}
					</a>
				{/each}
			</div>
		{:else}
			<div class="px-4 py-8 text-sm text-muted-foreground/70">当前人物还没有章节。</div>
		{/if}
	</section>
</section>
