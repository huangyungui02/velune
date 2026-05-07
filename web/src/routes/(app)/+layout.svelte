<script lang="ts">
	import { afterNavigate, disableScrollHandling } from '$app/navigation';
	import { navigating, page } from '$app/state';
	import DesktopSidebar from '$lib/components/app/DesktopSidebar.svelte';
	import MobileTabNav from '$lib/components/app/MobileTabNav.svelte';
	import SoulerDetailPageSkeleton from '$lib/components/souler/SoulerDetailPageSkeleton.svelte';
	import { pushRoute } from '$lib/stores/navigation-stack';
	import type { Snapshot } from './$types';
	import type { LayoutProps } from './$types';

	type AppLayoutSnapshot = {
		mainScrollTop: number;
	};

	let { data, children }: LayoutProps = $props();
	let mainScrollContainer = $state<HTMLElement | null>(null);
	let activePath = $derived(navigating.to?.url.pathname ?? page.url.pathname);
	let hideMobileNav = $derived(
		/^\/bookshelf\/[^/]+(?:\/(?:chapter\/[^/]+|profile))?$/.test(activePath) ||
			/^\/explore\/[^/]+$/.test(activePath)
	);
	let mainContentPadding = $derived(
		hideMobileNav
			? 'p-6 pb-4 md:p-10 md:pb-10 lg:p-12 lg:pb-12'
			: 'p-6 pb-32 md:p-10 md:pb-12 lg:p-12'
	);
	let showSoulerDetailSkeleton = $derived(
		/^\/explore\/[^/]+$/.test(navigating.to?.url.pathname ?? '')
	);
	const userEmail = $derived(data.user?.email ?? '');

	pushRoute(page.url);
	afterNavigate(({ to }) => {
		disableScrollHandling();
		if (to?.url) {
			pushRoute(to.url);
		}
	});

	function restoreMainScroll(top: number) {
		mainScrollContainer?.scrollTo({ top, behavior: 'auto' });
	}

	export const snapshot = {
		capture: () => ({
			mainScrollTop: mainScrollContainer?.scrollTop ?? 0
		}),
		restore: (value) => {
			restoreMainScroll(value.mainScrollTop);
		}
	} satisfies Snapshot<AppLayoutSnapshot>;
</script>

<div class="h-dvh w-full overflow-hidden">
	<div class="mx-auto grid h-full min-h-0 w-full max-w-7xl lg:grid-cols-[16rem_minmax(0,1fr)]">
		<DesktopSidebar {userEmail} />

		<main class="relative h-full min-h-0 min-w-0">
			<div
				bind:this={mainScrollContainer}
				class="scrollbar-soft h-full min-h-0 w-full overflow-y-auto overscroll-contain"
				data-main-scroll-container
			>
				<div class={mainContentPadding}>
					{#if showSoulerDetailSkeleton}
						<SoulerDetailPageSkeleton />
					{:else}
						{@render children()}
					{/if}
				</div>
			</div>
		</main>
	</div>

	{#if !hideMobileNav}
		<MobileTabNav />
	{/if}
</div>
