<script lang="ts">
	import { goto, preloadCode, preloadData } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { onMount } from 'svelte';
	import Compass from '@lucide/svelte/icons/compass';
	import LibraryBig from '@lucide/svelte/icons/library-big';
	import UserRound from '@lucide/svelte/icons/user-round';
	import { Button } from '$lib/components/ui/button/index.js';

	const tabs = [
		{ href: '/explore', label: '发现', icon: Compass },
		{ href: '/bookshelf', label: '书架', icon: LibraryBig },
		{ href: '/settings', label: '我的', icon: UserRound }
	] as const;
	type TabHref = (typeof tabs)[number]['href'];

	let optimisticPath = $derived<string>(page.url.pathname);

	function isActive(href: string) {
		return (
			optimisticPath === href || (href !== '/explore' && optimisticPath.startsWith(`${href}/`))
		);
	}

	function warmTab(href: TabHref) {
		void preloadCode(href);
		void preloadData(href);
	}

	function selectTab(event: MouseEvent, href: TabHref) {
		if (isActive(href)) {
			return;
		}

		event.preventDefault();
		optimisticPath = href;
		warmTab(href);
		void goto(resolve(href), { keepFocus: true });
	}

	onMount(() => {
		for (const tab of tabs) {
			warmTab(tab.href);
		}
	});
</script>

<nav
	class="fixed inset-x-4 bottom-4 z-30 grid grid-cols-3 gap-2 rounded-2xl border border-border/50 bg-background/80 p-2 shadow-sm backdrop-blur lg:hidden"
	data-sveltekit-preload-code="viewport"
>
	{#each tabs as tab (tab.href)}
		{@const Icon = tab.icon}
		<Button
			href={resolve(tab.href)}
			variant={isActive(tab.href) ? 'default' : 'ghost'}
			size="sm"
			class="h-10 gap-2 rounded-xl"
			onpointerdown={() => warmTab(tab.href)}
			onclick={(event) => selectTab(event, tab.href)}
		>
			<Icon class="size-4" />
			{tab.label}
		</Button>
	{/each}
</nav>
