<script lang="ts">
	import { Skeleton } from '$lib/components/ui/skeleton/index.js';

	const tagSkeletons = ['tag-a', 'tag-b', 'tag-c', 'tag-d'];
	const paragraphSkeletons = ['line-a', 'line-b', 'line-c', 'line-d', 'line-e'];
	const chapterSkeletons = ['chapter-a', 'chapter-b', 'chapter-c'];
</script>

<section
	class="mx-auto max-w-5xl space-y-10 pt-[calc(env(safe-area-inset-top)+3.4rem)] md:pt-0"
	aria-busy="true"
	aria-label="人物资料加载中"
>
	<header class="fixed inset-x-0 top-0 z-40 border-b border-border/35 bg-background/70 md:hidden">
		<div
			class="grid grid-cols-[2.25rem_1fr_2.25rem] items-center gap-2 px-3 pt-[max(env(safe-area-inset-top),0.4rem)] pb-2"
		>
			<Skeleton class="size-9 rounded-full" />
			<Skeleton class="mx-auto h-4 w-20 rounded-full" />
			<span class="size-9" aria-hidden="true"></span>
		</div>
	</header>

	<header class="hidden max-w-3xl md:block">
		<Skeleton class="mb-3 h-3 w-20 rounded-full" />
		<Skeleton class="h-8 w-32 rounded-full" />
		<div class="mt-5 h-px bg-border/45"></div>
	</header>

	<section
		class="grid grid-cols-[6.5rem_minmax(0,1fr)] items-start gap-x-4 gap-y-6 md:grid-cols-[11rem_minmax(0,42rem)] md:gap-x-8"
	>
		<Skeleton
			class="aspect-[3/4] w-full rounded-2xl bg-muted/45 md:row-span-2 md:rounded-xl"
		/>

		<div class="min-w-0 space-y-4 pt-1">
			<Skeleton class="h-7 w-24 rounded-full md:hidden" />
			<div class="flex flex-wrap gap-2">
				{#each tagSkeletons as item (item)}
					<Skeleton class="h-6 w-14 rounded-full md:h-7 md:w-16" />
				{/each}
			</div>
		</div>

		<div class="col-span-2 space-y-3 md:col-span-1 md:col-start-2 md:max-w-[64ch]">
			{#each paragraphSkeletons as item, index (item)}
				<Skeleton class={['h-4 rounded-full', index === paragraphSkeletons.length - 1 ? 'w-3/5' : 'w-full']} />
			{/each}
		</div>
	</section>

	<section class="max-w-3xl border-t border-border/45 pt-4">
		<div class="divide-y divide-border/45">
			{#each chapterSkeletons as item (item)}
				<div class="py-5 md:px-2">
					<Skeleton class="mb-3 h-3 w-8 rounded-full" />
					<Skeleton class="h-7 w-48 rounded-full" />
					<Skeleton class="mt-3 h-4 w-3/4 rounded-full" />
				</div>
			{/each}
		</div>
	</section>
</section>
