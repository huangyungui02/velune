<script lang="ts">
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();

	const createDraftName = $derived(form?.action === 'createSouler' ? (form.name ?? '') : '');
	const createDraftLanguage = $derived(
		form?.action === 'createSouler' ? (form.language ?? 'zh') : 'zh'
	);

	function isActiveSouler(soulerId: string) {
		return data.selectedSoulerId === soulerId;
	}

	function soulerHref(soulerId: string) {
		return `/admin?souler=${encodeURIComponent(soulerId)}`;
	}
</script>

<svelte:head>
	<title>Velune · 管理</title>
</svelte:head>

<section class="space-y-6">
	<header class="space-y-2">
		<h1 class="text-3xl leading-tight text-primary">Souler 管理后台</h1>
		<p class="text-sm text-muted-foreground">仅 admin 可访问。分栏查看、编辑与新建人物。</p>
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

	<div class="grid gap-4 xl:grid-cols-3">
		<section class="rounded-2xl border border-border/70 bg-background/55 p-4">
			<header class="mb-3 flex items-center justify-between">
				<h2 class="text-xl text-primary">未审核</h2>
				<span class="text-xs text-muted-foreground">{data.uncheckedSoulers.length}</span>
			</header>
			<div class="grid gap-2">
				{#if data.uncheckedSoulers.length > 0}
					{#each data.uncheckedSoulers as souler (souler.id)}
						<a
							href={soulerHref(souler.id)}
							class={`grid grid-cols-[3rem_1fr] gap-2 rounded-xl border p-2 transition ${
								isActiveSouler(souler.id)
									? 'border-primary/35 bg-primary/10'
									: 'border-border/70 bg-card/70 hover:bg-card'
							}`}
						>
							<div class="relative aspect-[3/4] overflow-hidden rounded-md border border-border/70 bg-muted/30">
								{#if souler.imageUrl}
									<img src={souler.imageUrl} alt={souler.name} class="h-full w-full object-cover" />
								{:else}
									<div class="grid h-full place-items-center text-[10px] text-muted-foreground">无图</div>
								{/if}
							</div>
							<div class="min-w-0">
								<p class="truncate text-sm leading-6">{souler.name}</p>
								<p class="text-xs text-muted-foreground">{souler.lang}</p>
							</div>
						</a>
					{/each}
				{:else}
					<p class="rounded-xl border border-dashed border-border px-3 py-4 text-xs text-muted-foreground">
						暂无未审核人物。
					</p>
				{/if}
			</div>
		</section>

		<section class="rounded-2xl border border-border/70 bg-background/55 p-4">
			<header class="mb-3 flex items-center justify-between">
				<h2 class="text-xl text-primary">已审核</h2>
				<span class="text-xs text-muted-foreground">{data.checkedSoulers.length}</span>
			</header>
			<div class="grid gap-2">
				{#if data.checkedSoulers.length > 0}
					{#each data.checkedSoulers as souler (souler.id)}
						<a
							href={soulerHref(souler.id)}
							class={`grid grid-cols-[3rem_1fr] gap-2 rounded-xl border p-2 transition ${
								isActiveSouler(souler.id)
									? 'border-primary/35 bg-primary/10'
									: 'border-border/70 bg-card/70 hover:bg-card'
							}`}
						>
							<div class="relative aspect-[3/4] overflow-hidden rounded-md border border-border/70 bg-muted/30">
								{#if souler.imageUrl}
									<img src={souler.imageUrl} alt={souler.name} class="h-full w-full object-cover" />
								{:else}
									<div class="grid h-full place-items-center text-[10px] text-muted-foreground">无图</div>
								{/if}
							</div>
							<div class="min-w-0">
								<p class="truncate text-sm leading-6">{souler.name}</p>
								<p class="text-xs text-muted-foreground">{souler.lang}</p>
							</div>
						</a>
					{/each}
				{:else}
					<p class="rounded-xl border border-dashed border-border px-3 py-4 text-xs text-muted-foreground">
						暂无已审核人物。
					</p>
				{/if}
			</div>
		</section>

		<section class="rounded-2xl border border-border/70 bg-background/55 p-4">
			<header class="mb-3 space-y-1">
				<h2 class="text-xl text-primary">新建 Souler</h2>
				<p class="text-xs text-muted-foreground">输入名字 + 语言，先查重，再用大模型生成 canonical name。</p>
			</header>

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
	</div>

	{#if data.selectedSouler}
		<section class="space-y-4 rounded-2xl border border-border/70 bg-background/55 p-4 md:p-5">
			<header class="flex flex-wrap items-end gap-3">
				<h2 class="text-2xl text-primary">编辑人物</h2>
				<p class="text-sm text-muted-foreground">{data.selectedSouler.canonicalName || '暂无 canonical name'}</p>
			</header>

			<div class="grid gap-5 lg:grid-cols-[12rem_1fr]">
				<div class="space-y-3">
					<div
						class="relative aspect-[3/4] overflow-hidden rounded-xl border border-border/70 bg-muted/30"
					>
						{#if data.selectedSouler.imageUrl}
							<img
								src={data.selectedSouler.imageUrl}
								alt={data.selectedSouler.name}
								class="h-full w-full object-cover"
							/>
						{:else}
							<div class="grid h-full place-items-center text-sm text-muted-foreground">暂无头像</div>
						{/if}
					</div>

					<form method="POST" enctype="multipart/form-data" class="grid gap-2">
						<input type="hidden" name="souler_id" value={data.selectedSouler.id} />
						<input
							type="file"
							name="avatar"
							accept="image/*"
							class="block w-full text-xs text-muted-foreground file:mr-2 file:rounded-lg file:border file:border-border file:bg-card file:px-2 file:py-1 file:text-xs"
							required
						/>
						<button
							class="h-9 rounded-xl border border-primary/25 bg-primary/10 text-sm text-primary transition hover:bg-primary/15"
							formaction="?/uploadAvatar"
						>
							上传头像
						</button>
					</form>
				</div>

				<div class="space-y-4">
					<form method="POST" class="grid gap-3">
						<input type="hidden" name="souler_id" value={data.selectedSouler.id} />
						<input type="hidden" name="lang" value={data.selectedSouler.lang} />

						<div class="grid gap-3 md:grid-cols-[1fr_auto]">
							<label class="grid gap-1.5">
								<span class="text-xs text-muted-foreground">人物名</span>
								<input
									class="h-10 rounded-xl border border-input bg-background/70 px-3 text-sm outline-none focus:border-primary/60"
									name="name"
									value={data.selectedSouler.name}
									required
								/>
							</label>

							<label class="grid h-10 self-end rounded-xl border border-border/70 bg-card/80 px-3 text-sm">
								<span class="inline-flex h-full items-center gap-2">
									<input
										type="checkbox"
										name="checked"
										checked={data.selectedSouler.checked}
										class="size-4 rounded border-border"
									/>
									已审核
								</span>
							</label>
						</div>

						<label class="grid gap-1.5">
							<span class="text-xs text-muted-foreground">关键词（逗号分隔）</span>
							<input
								class="h-10 rounded-xl border border-input bg-background/70 px-3 text-sm outline-none focus:border-primary/60"
								name="keywords"
								value={data.selectedSouler.keywords.join(', ')}
								placeholder="存在主义, 诗性, 意志 ..."
							/>
						</label>

						<label class="grid gap-1.5">
							<span class="text-xs text-muted-foreground">简介</span>
							<textarea
								class="min-h-32 rounded-xl border border-input bg-background/70 px-3 py-2 text-sm leading-6 outline-none focus:border-primary/60"
								name="bio"
							>{data.selectedSouler.bio}</textarea>
						</label>

						<button
							class="h-10 rounded-xl border border-primary/30 bg-primary px-4 text-sm font-medium text-primary-foreground transition hover:opacity-90"
							formaction="?/saveSouler"
						>
							保存人物信息
						</button>
					</form>

					<form method="POST" class="space-y-3">
						<input type="hidden" name="souler_id" value={data.selectedSouler.id} />
						<div class="flex items-center justify-between">
							<h3 class="text-xl text-primary">章节</h3>
							<span class="text-xs text-muted-foreground">{data.selectedSouler.chapters.length} 条</span>
						</div>

						{#if data.selectedSouler.chapters.length > 0}
							<div class="grid gap-3">
								{#each data.selectedSouler.chapters as chapter (chapter.id)}
									<div class="rounded-xl border border-border/70 bg-card/75 p-3">
										<input type="hidden" name="chapter_id" value={chapter.id} />
										<div class="grid gap-2">
											<p class="text-xs text-muted-foreground">第 {chapter.seq} 章</p>
											<input
												class="h-9 rounded-lg border border-input bg-background/70 px-3 text-sm outline-none focus:border-primary/60"
												name="chapter_title"
												value={chapter.title}
												required
											/>
											<input
												class="h-9 rounded-lg border border-input bg-background/70 px-3 text-sm outline-none focus:border-primary/60"
												name="chapter_subtitle"
												value={chapter.subtitle}
												required
											/>
										</div>
									</div>
								{/each}
							</div>
							<button
								class="h-10 rounded-xl border border-primary/30 bg-primary px-4 text-sm font-medium text-primary-foreground transition hover:opacity-90"
								formaction="?/saveChapters"
							>
								保存章节
							</button>
						{:else}
							<div
								class="rounded-xl border border-dashed border-border px-4 py-6 text-sm text-muted-foreground"
							>
								当前人物没有章节，暂时无法编辑。
							</div>
						{/if}
					</form>
				</div>
			</div>
		</section>
	{:else}
		<div class="rounded-2xl border border-dashed border-border px-4 py-8 text-sm text-muted-foreground">
			请选择一个 souler 进入编辑。
		</div>
	{/if}
</section>
