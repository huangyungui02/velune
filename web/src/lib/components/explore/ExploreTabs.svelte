<script lang="ts">
	import { Button } from '$lib/components/ui/button/index.js';
	import type { ExploreTab } from '$lib/stores/explore-view-state';

	let {
		activeTab,
		onSelect
	}: {
		activeTab: ExploreTab;
		onSelect: (tab: ExploreTab) => void;
	} = $props();
</script>

<div class="inline-flex rounded-2xl border border-border/50 bg-muted/20 p-1">
	<Button
		type="button"
		variant={activeTab === 'featured' ? 'default' : 'ghost'}
		size="sm"
		class="rounded-xl px-4"
		onclick={() => onSelect('featured')}
	>
		精选
	</Button>
	<Button
		type="button"
		variant={activeTab === 'latest' ? 'default' : 'ghost'}
		size="sm"
		class="rounded-xl px-4"
		onclick={() => onSelect('latest')}
	>
		最新
	</Button>
</div>
