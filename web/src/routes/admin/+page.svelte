<script lang="ts">
	import AdminSoulerListCard from '$lib/components/admin/AdminSoulerListCard.svelte';
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
	<header class="space-y-1">
		<h1 class="text-3xl leading-tight text-primary">
			{data.activeTab === 'create' ? '新建 Souler' : data.activeTab === 'checked' ? '已审核列表' : '待审核列表'}
		</h1>
		<p class="text-sm text-muted-foreground">
			{data.activeTab === 'create'
				? '输入名字与语言，先查重，再生成 canonical name 并写入数据库。'
				: '右侧只展示列表，点击“去编辑”进入详情页。'}
		</p>
	</header>

	{#if data.notice}
		<p class="rounded-2xl border border-primary/25 bg-primary/10 px-4 py-3 text-sm text-primary">
			{data.notice}
		</p>
	{/if}

	{#if form?.message}
		<p class="rounded-2xl border border-destructive/25 bg-destructive/10 px-4 py-3 text-sm text-destructive">
			{form.message}
		</p>
	{/if}

	{#if data.activeTab === 'create'}
		<section class="max-w-xl rounded-2xl border border-border/70 bg-background/55 p-4">
			<form method="POST" class="grid gap-3">
				<label class="grid gap-1.5">
					<span class="text-xs text-muted-foreground">名字</span>
					<input
						class="h-10 rounded-xl border border-input bg-background/70 px-3 text-sm outline-none focus:border-primary/60"
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
						class="h-10 rounded-xl border border-input bg-background/70 px-3 text-sm outline-none focus:border-primary/60"
					>
						<option value="zh" selected={createDraftLanguage === 'zh'}>zh</option>
						<option value="en" selected={createDraftLanguage === 'en'}>en</option>
					</select>
				</label>

				<button
					class="h-10 rounded-xl border border-primary/30 bg-primary px-3 text-sm font-medium text-primary-foreground transition hover:opacity-90"
					formaction="?/createSouler"
				>
					判断重复并创建
				</button>
			</form>
		</section>
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
				<p class="rounded-2xl border border-dashed border-border px-4 py-8 text-sm text-muted-foreground">
					当前分组没有 souler。
				</p>
			{/if}
		</section>
	{/if}
</section>
