<script lang="ts">
	import AccountPanel from '$lib/components/app/AccountPanel.svelte';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	const email = $derived(data.user?.email ?? '未知用户');
</script>

<svelte:head>
	<title>Velune Folio · 我的</title>
</svelte:head>

<section class="mx-auto flex min-h-[72dvh] w-full max-w-xl flex-col">
	<header class="space-y-2">
		<h1 class="text-2xl leading-tight text-primary">我的</h1>
		<Separator class="mt-3" />
	</header>

	<AccountPanel email={email} class="mt-6 flex-1" />
</section>
