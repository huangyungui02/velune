<script lang="ts">
	import { page } from '$app/state';
	import Compass from '@lucide/svelte/icons/compass';
	import LibraryBig from '@lucide/svelte/icons/library-big';
	import UserRound from '@lucide/svelte/icons/user-round';
	import { Button } from '$lib/components/ui/button/index.js';

	function isActive(href: string) {
		return (
			page.url.pathname === href ||
			(href !== '/explore' && page.url.pathname.startsWith(`${href}/`))
		);
	}
</script>

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
