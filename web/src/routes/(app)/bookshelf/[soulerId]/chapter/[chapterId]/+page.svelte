<script lang="ts">
	import ChapterConversation from '$lib/components/chapter/ChapterConversation.svelte';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	const conversationKey = $derived(
		`${data.souler.id}:${data.chapter.id}:${data.initialSessionId ?? 'new'}`
	);
</script>

<svelte:head>
	<title>Velune Folio · {data.chapter.title}</title>
</svelte:head>

{#key conversationKey}
	<ChapterConversation
		souler={data.souler}
		chapter={data.chapter}
		initialSessionId={data.initialSessionId}
		initialMessages={data.initialMessages}
	/>
{/key}
