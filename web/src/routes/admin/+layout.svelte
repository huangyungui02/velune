<script lang="ts">
	import ClipboardCheck from '@lucide/svelte/icons/clipboard-check';
	import FilePlus2 from '@lucide/svelte/icons/file-plus-2';
	import Files from '@lucide/svelte/icons/files';
	import Sparkles from '@lucide/svelte/icons/sparkles';
	import { page } from '$app/state';
	import { Button } from '$lib/components/ui/button/index.js';
	import * as Card from '$lib/components/ui/card/index.js';
	import { ScrollArea } from '$lib/components/ui/scroll-area/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import type { LayoutProps } from './$types';

	let { data, children }: LayoutProps = $props();
	const isDiscoverRoute = $derived(page.url.pathname.startsWith('/admin/discover'));
</script>

<svelte:head>
	<title>Velune · Admin</title>
</svelte:head>

<div class="h-dvh w-full overflow-hidden px-4 py-5 md:px-6 lg:px-8">
	<div class="mx-auto grid h-full min-h-0 w-full max-w-7xl gap-5 lg:grid-cols-[15rem_1fr]">
		<Card.Root class="h-full min-h-0 rounded-3xl bg-card/82 py-0 ring-1 ring-border/72">
			<Card.Header class="space-y-2 px-4 pt-4">
				<p class="font-hand text-3xl leading-none text-primary">Velune Admin</p>
				<p class="truncate text-xs text-muted-foreground">{data.userEmail}</p>
			</Card.Header>

			<Separator class="mx-4" />

			<ScrollArea
				class="min-h-0 flex-1 p-4"
				scrollbarYClasses="data-vertical:w-2 data-vertical:border-l-0"
			>
				<nav class="grid gap-2">
					<Button
						href="/admin?tab=unchecked"
						variant={data.activeTab === 'unchecked' ? 'default' : 'outline'}
						size="sm"
						class="h-10 justify-start gap-2 rounded-2xl"
					>
						<Files class="size-4" />
						待审核
						<span class="ml-auto text-xs opacity-80">{data.uncheckedSoulers.length}</span>
					</Button>
					<Button
						href="/admin?tab=checked"
						variant={data.activeTab === 'checked' ? 'default' : 'outline'}
						size="sm"
						class="h-10 justify-start gap-2 rounded-2xl"
					>
						<ClipboardCheck class="size-4" />
						已审核
						<span class="ml-auto text-xs opacity-80">{data.checkedSoulers.length}</span>
					</Button>
					<Button
						href="/admin?tab=create"
						variant={data.activeTab === 'create' ? 'default' : 'outline'}
						size="sm"
						class="h-10 justify-start gap-2 rounded-2xl"
					>
						<FilePlus2 class="size-4" />
						新建
					</Button>
					<Button
						href="/admin?tab=sections"
						variant={isDiscoverRoute || data.activeTab === 'sections' ? 'default' : 'outline'}
						size="sm"
						class="h-10 justify-start gap-2 rounded-2xl"
					>
						<Sparkles class="size-4" />
						精选分组
						<span class="ml-auto text-xs opacity-80">{data.discoverSectionCount}</span>
					</Button>
				</nav>
			</ScrollArea>
		</Card.Root>

		<Card.Root class="h-full min-h-0 rounded-3xl bg-card/72 py-0 ring-1 ring-border/70">
			<ScrollArea
				class="h-full min-h-0 rounded-[inherit]"
				scrollbarYClasses="data-vertical:w-2 data-vertical:border-l-0"
			>
				<main class="p-5 md:p-7">
					{@render children()}
				</main>
			</ScrollArea>
		</Card.Root>
	</div>
</div>
