<script lang="ts">
	import type { LayoutProps } from './$types';

	let { data, children }: LayoutProps = $props();

	function tabClass(tab: 'unchecked' | 'checked' | 'create') {
		return data.activeTab === tab
			? 'border-primary/25 bg-primary text-primary-foreground'
			: 'border-border/70 bg-card/70 text-foreground hover:bg-accent/45';
	}
</script>

<svelte:head>
	<title>Velune · Admin</title>
</svelte:head>

<div class="mx-auto w-full max-w-7xl px-4 py-5 md:px-6 lg:px-8">
	<div class="grid min-h-[calc(100dvh-2.5rem)] gap-5 lg:grid-cols-[15rem_1fr]">
		<aside class="rounded-3xl border border-border/70 bg-card/80 p-4">
			<div class="space-y-2 px-2 pb-4">
				<p class="font-hand text-3xl leading-none text-primary">Velune Admin</p>
				<p class="text-xs text-muted-foreground">{data.userEmail}</p>
			</div>

			<nav class="grid gap-2">
				<a
					href="/admin?tab=unchecked"
					class={`rounded-2xl border px-3 py-2 text-sm transition ${tabClass('unchecked')}`}
				>
					待审核
					<span class="ml-2 text-xs opacity-80">{data.uncheckedSoulers.length}</span>
				</a>
				<a
					href="/admin?tab=checked"
					class={`rounded-2xl border px-3 py-2 text-sm transition ${tabClass('checked')}`}
				>
					已审核
					<span class="ml-2 text-xs opacity-80">{data.checkedSoulers.length}</span>
				</a>
				<a
					href="/admin?tab=create"
					class={`rounded-2xl border px-3 py-2 text-sm transition ${tabClass('create')}`}
				>
					新建
				</a>
			</nav>
		</aside>

		<main class="rounded-3xl border border-border/70 bg-card/70 p-5 md:p-7">
			{@render children()}
		</main>
	</div>
</div>
