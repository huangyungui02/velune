<script lang="ts">
	import AdminDiscoverSectionListCard from '$lib/components/admin/AdminDiscoverSectionListCard.svelte';
	import AdminSoulerListCard from '$lib/components/admin/AdminSoulerListCard.svelte';
	import { Badge } from '$lib/components/ui/badge/index.js';
	import { Button } from '$lib/components/ui/button/index.js';
	import * as Card from '$lib/components/ui/card/index.js';
	import { Input } from '$lib/components/ui/input/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import { Textarea } from '$lib/components/ui/textarea/index.js';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();

	const createDraftName = $derived(form?.action === 'createSouler' ? (form.name ?? '') : '');
	const createDraftLanguage = $derived(
		form?.action === 'createSouler' ? (form.language ?? 'zh') : 'zh'
	);
	const sectionForm = $derived(
		form?.action === 'createSection' ? (form as Record<string, string | undefined>) : null
	);
	const sectionDraftLang = $derived(sectionForm?.lang ?? 'zh');
	const sectionDraftTitle = $derived(sectionForm?.title ?? '');
	const sectionDraftSubtitle = $derived(sectionForm?.subtitle ?? '');
	const sectionDraftSortOrder = $derived(sectionForm?.sort_order ?? '0');
	const pendingRequestId = $derived(form?.action === 'createSouler' ? form.requestId : null);

	$effect(() => {
		if (!pendingRequestId) {
			return;
		}

		let cancelled = false;
		const timer = window.setInterval(async () => {
			const response = await fetch(
				`/api/admin/souler-resolutions/${encodeURIComponent(String(pendingRequestId))}`
			);
			const payload = await response.json().catch(() => null);
			if (cancelled || !payload) {
				return;
			}
			if (payload.soulerId) {
				window.location.href = `/admin/${encodeURIComponent(payload.soulerId)}?tab=create&ok=created`;
			}
		}, 1800);

		return () => {
			cancelled = true;
			window.clearInterval(timer);
		};
	});

	function detailHref(soulerId: string) {
		return `/admin/${encodeURIComponent(soulerId)}?tab=${data.activeTab}`;
	}

	function sectionDetailHref(sectionId: string) {
		return `/admin/discover/${encodeURIComponent(sectionId)}?tab=sections`;
	}
</script>

<section class="space-y-5">
	<header class="space-y-2">
		<h1 class="text-2xl leading-tight text-primary">
			{data.activeTab === 'create'
				? '新建 Souler'
				: data.activeTab === 'sections'
					? '精选分组'
					: data.activeTab === 'checked'
						? '已审核列表'
						: '待审核列表'}
		</h1>
		<p class="text-sm text-muted-foreground">
			{data.activeTab === 'create'
				? '输入名字与语言，先查重，再生成 canonical name 并写入数据库。'
				: data.activeTab === 'sections'
					? '管理发现页分组，支持多语言分组与分组内人物排序。'
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
		<Card.Root
			class={pendingRequestId
				? 'rounded-2xl bg-primary/9 px-4 py-3 ring-1 ring-primary/24'
				: 'rounded-2xl bg-destructive/10 px-4 py-3 ring-1 ring-destructive/25'}
		>
			<Card.Content class={pendingRequestId ? 'p-0 text-sm text-primary' : 'p-0 text-sm text-destructive'}
				>{form.message}</Card.Content
			>
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
						{pendingRequestId ? '正在创建' : '判断重复并创建'}
					</Button>
				</form>
			</Card.Content>
		</Card.Root>
	{:else if data.activeTab === 'sections'}
		<div class="grid gap-4 xl:grid-cols-[minmax(0,26rem)_1fr]">
			<Card.Root class="rounded-2xl bg-background/58 py-4 ring-1 ring-border/70">
				<Card.Content class="grid gap-3 px-4">
					<header class="space-y-1">
						<h2 class="text-xl text-primary">新建精选分组</h2>
						<p class="text-xs text-muted-foreground">按语言维护发现页精选列表。</p>
					</header>
					<form method="POST" class="grid gap-3">
						<label class="grid gap-1.5">
							<span class="text-xs text-muted-foreground">语言</span>
							<select
								name="lang"
								class="h-10 rounded-xl border border-input bg-background/72 px-3 text-sm outline-none focus:border-primary/60"
							>
								<option value="zh" selected={sectionDraftLang === 'zh'}>zh</option>
								<option value="en" selected={sectionDraftLang === 'en'}>en</option>
								<option value="ja" selected={sectionDraftLang === 'ja'}>ja</option>
							</select>
						</label>
						<label class="grid gap-1.5">
							<span class="text-xs text-muted-foreground">标题</span>
							<Input
								class="h-10 rounded-xl bg-background/72 text-sm"
								name="title"
								placeholder="存在与虚无"
								value={sectionDraftTitle}
								required
							/>
						</label>
						<label class="grid gap-1.5">
							<span class="text-xs text-muted-foreground">副标题（可选）</span>
							<Textarea
								class="min-h-20 rounded-xl bg-background/72 text-sm leading-6"
								name="subtitle"
								placeholder="可写一句选题说明"
								value={sectionDraftSubtitle}
							/>
						</label>
						<label class="grid gap-1.5">
							<span class="text-xs text-muted-foreground">排序</span>
							<Input
								class="h-10 rounded-xl bg-background/72 text-sm"
								type="number"
								name="sort_order"
								value={sectionDraftSortOrder}
							/>
						</label>

						<Button class="h-10 rounded-xl text-sm" type="submit" formaction="?/createSection">
							创建分组
						</Button>
					</form>
				</Card.Content>
			</Card.Root>

			<section class="space-y-3">
				<div class="flex items-center justify-between">
					<h2 class="text-xl text-primary">分组列表</h2>
					<Badge variant="outline" class="text-[0.7rem]">{data.discoverSections.length} 组</Badge>
				</div>
				{#if data.discoverSections.length > 0}
					<div class="grid gap-3 md:grid-cols-2">
						{#each data.discoverSections as section (section.id)}
							<AdminDiscoverSectionListCard
								href={sectionDetailHref(section.id)}
								title={section.title}
								subtitle={section.subtitle}
								lang={section.lang}
								sortOrder={section.sortOrder}
								itemCount={section.itemCount}
								isActive={section.isActive}
							/>
						{/each}
					</div>
				{:else}
					<Card.Root class="rounded-2xl border-dashed px-4 py-8 ring-1 ring-border">
						<Card.Content class="p-0 text-sm text-muted-foreground"
							>当前还没有精选分组。</Card.Content
						>
					</Card.Root>
				{/if}
			</section>
		</div>
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
