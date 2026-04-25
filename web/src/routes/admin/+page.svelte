<script lang="ts">
	import AdminSoulerListCard from '$lib/components/admin/AdminSoulerListCard.svelte';
	import { Button } from '$lib/components/ui/button/index.js';
	import * as Card from '$lib/components/ui/card/index.js';
	import { Input } from '$lib/components/ui/input/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();

	const createDraftName = $derived(form?.action === 'createSouler' ? (form.name ?? '') : '');
	const createDraftLanguage = $derived(
		form?.action === 'createSouler' ? (form.language ?? 'zh') : 'zh'
	);

	function detailHref(soulerId: string) {
		return `/admin/${encodeURIComponent(soulerId)}?tab=${data.activeTab}`;
	}
</script>

<section class="space-y-5">
	<header class="space-y-2">
		<h1 class="text-3xl leading-tight text-primary">
			{data.activeTab === 'create'
				? '新建 Souler'
				: data.activeTab === 'checked'
					? '已审核列表'
					: '待审核列表'}
		</h1>
		<p class="text-sm text-muted-foreground">
			{data.activeTab === 'create'
				? '输入名字与语言，先查重，再生成 canonical name 并写入数据库。'
				: '右侧只展示列表，点击「去编辑」进入详情页。'}
		</p>
		<Separator class="mt-3" />
	</header>

	{#if data.notice}
		<Card.Root class="rounded-2xl bg-primary/9 px-4 py-3 ring-1 ring-primary/24">
			<Card.Content class="p-0 text-sm text-primary">{data.notice}</Card.Content>
		</Card.Root>
	{/if}

	{#if form?.message}
		<Card.Root class="rounded-2xl bg-destructive/10 px-4 py-3 ring-1 ring-destructive/25">
			<Card.Content class="p-0 text-sm text-destructive">{form.message}</Card.Content>
		</Card.Root>
	{/if}

	{#if data.activeTab === 'create'}
		<Card.Root class="max-w-xl rounded-2xl bg-background/58 py-4 ring-1 ring-border/70">
			<Card.Content class="grid gap-3 px-4">
				<form method="POST" class="grid gap-3">
					<label class="grid gap-1.5">
						<span class="text-xs text-muted-foreground">名字</span>
						<Input
							class="h-10 rounded-xl bg-background/72 text-sm"
							name="name"
							placeholder="例如：尼采"
							value={createDraftName}
							required
						/>
					</label>

					<label class="grid gap-1.5">
						<span class="text-xs text-muted-foreground">语言</span>
						<select
							name="language"
							class="h-10 rounded-xl border border-input bg-background/72 px-3 text-sm outline-none focus:border-primary/60"
						>
							<option value="zh" selected={createDraftLanguage === 'zh'}>zh</option>
							<option value="en" selected={createDraftLanguage === 'en'}>en</option>
						</select>
					</label>

					<Button class="h-10 rounded-xl text-sm" type="submit" formaction="?/createSouler">
						判断重复并创建
					</Button>
				</form>
			</Card.Content>
		</Card.Root>
	{:else}
		<section class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
			{#if data.visibleSoulers.length > 0}
				{#each data.visibleSoulers as souler (souler.id)}
					<AdminSoulerListCard
						href={detailHref(souler.id)}
						name={souler.name}
						lang={souler.lang}
						imageUrl={souler.imageUrl}
					/>
				{/each}
			{:else}
				<Card.Root
					class="rounded-2xl border-dashed px-4 py-8 ring-1 ring-border md:col-span-2 xl:col-span-3"
				>
					<Card.Content class="p-0 text-sm text-muted-foreground"
						>当前分组没有 souler。</Card.Content
					>
				</Card.Root>
			{/if}
		</section>
	{/if}
</section>
