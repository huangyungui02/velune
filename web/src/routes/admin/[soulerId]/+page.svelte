<script lang="ts">
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();

	const backHref = $derived(`/admin?tab=${data.tab}`);
	const wikidataUrl = $derived(
		data.souler.wikidata ? `https://www.wikidata.org/wiki/${encodeURIComponent(data.souler.wikidata)}` : ''
	);
	const keywordRows = $derived.by(() => {
		const extraRows = Math.max(4, 8 - data.souler.keywords.length);
		return [
			...data.souler.keywords,
			...Array.from({ length: extraRows }, () => ({
				word: '',
				weight: 0.5
			}))
		];
	});
</script>

<section class="space-y-5">
	<header class="space-y-2">
		<a href={backHref} class="inline-flex text-sm text-muted-foreground transition hover:text-foreground"
			>返回列表</a
		>
		<h1 class="text-3xl leading-tight text-primary">编辑人物</h1>
		<p class="text-sm text-muted-foreground">{data.souler.canonicalName || '暂无 canonical name'}</p>
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

	<div class="grid gap-5 lg:grid-cols-[12rem_1fr]">
		<div class="space-y-3">
			<div class="relative aspect-[3/4] overflow-hidden rounded-xl border border-border/70 bg-muted/30">
				{#if data.souler.imageUrl}
					<img src={data.souler.imageUrl} alt={data.souler.name} class="h-full w-full object-cover" />
				{:else}
					<div class="grid h-full place-items-center text-sm text-muted-foreground">暂无头像</div>
				{/if}
			</div>

			<form method="POST" enctype="multipart/form-data" class="grid gap-2">
				<input type="hidden" name="souler_id" value={data.souler.id} />
				<input type="hidden" name="tab" value={data.tab} />
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
				<input type="hidden" name="souler_id" value={data.souler.id} />
				<input type="hidden" name="lang" value={data.souler.lang} />
				<input type="hidden" name="tab" value={data.tab} />

				<div class="grid gap-3 md:grid-cols-[1fr_auto]">
					<label class="grid gap-1.5">
						<span class="text-xs text-muted-foreground">人物名</span>
						<input
							class="h-10 rounded-xl border border-input bg-background/70 px-3 text-sm outline-none focus:border-primary/60"
							name="name"
							value={data.souler.name}
							required
						/>
					</label>

					<label class="grid h-10 self-end rounded-xl border border-border/70 bg-card/80 px-3 text-sm">
						<span class="inline-flex h-full items-center gap-2">
							<input
								type="checkbox"
								name="checked"
								checked={data.souler.checked}
								class="size-4 rounded border-border"
							/>
							已审核
						</span>
					</label>
				</div>

				<label class="grid gap-1.5">
					<span class="text-xs text-muted-foreground">Wikidata</span>
					<input
						class="h-10 rounded-xl border border-input bg-background/70 px-3 text-sm outline-none focus:border-primary/60"
						name="wikidata"
						value={data.souler.wikidata}
						placeholder="例如：Q937"
					/>
				</label>

				{#if wikidataUrl}
					<a
						href={wikidataUrl}
						target="_blank"
						rel="noreferrer"
						class="inline-flex text-xs text-primary underline-offset-4 hover:underline"
					>
						打开 Wikidata 条目
					</a>
				{/if}

				<label class="grid gap-1.5">
					<span class="text-xs text-muted-foreground">简介</span>
					<textarea
						class="min-h-28 rounded-xl border border-input bg-background/70 px-3 py-2 text-sm leading-6 outline-none focus:border-primary/60"
						name="bio"
					>{data.souler.bio}</textarea>
				</label>

				<div class="space-y-2">
					<p class="text-xs text-muted-foreground">关键词与权重</p>
					<div class="grid gap-2">
						{#each keywordRows as row, index (`${row.word}-${index}`)}
							<div class="grid grid-cols-[1fr_8rem] gap-2">
								<input
									class="h-9 rounded-lg border border-input bg-background/70 px-3 text-sm outline-none focus:border-primary/60"
									name="keyword_word"
									value={row.word}
									placeholder="关键词"
								/>
								<input
									type="number"
									name="keyword_weight"
									min="0"
									max="1"
									step="0.01"
									class="h-9 rounded-lg border border-input bg-background/70 px-3 text-sm outline-none focus:border-primary/60"
									value={row.weight}
								/>
							</div>
						{/each}
					</div>
				</div>

				<button
					class="h-10 rounded-xl border border-primary/30 bg-primary px-4 text-sm font-medium text-primary-foreground transition hover:opacity-90"
					formaction="?/saveSouler"
				>
					保存人物信息
				</button>
			</form>

			<form method="POST" class="space-y-3">
				<input type="hidden" name="souler_id" value={data.souler.id} />
				<input type="hidden" name="tab" value={data.tab} />

				<div class="flex items-center justify-between">
					<h3 class="text-xl text-primary">章节</h3>
					<span class="text-xs text-muted-foreground">{data.souler.chapters.length} 条</span>
				</div>

				{#if data.souler.chapters.length > 0}
					<div class="grid gap-3">
						{#each data.souler.chapters as chapter (chapter.id)}
							<div class="rounded-xl border border-border/70 bg-card/75 p-3">
								<input type="hidden" name="chapter_id" value={chapter.id} />
								<div class="grid gap-2">
									<p class="text-xs text-muted-foreground">第 {chapter.seq} 章</p>
									<input
										class="h-9 rounded-lg border border-input bg-background/70 px-3 text-sm outline-none focus:border-primary/60"
										name="chapter_title"
										value={chapter.title}
										placeholder="标题"
										required
									/>
									<input
										class="h-9 rounded-lg border border-input bg-background/70 px-3 text-sm outline-none focus:border-primary/60"
										name="chapter_subtitle"
										value={chapter.subtitle}
										placeholder="副标题"
										required
									/>
									<input
										class="h-9 rounded-lg border border-input bg-background/70 px-3 text-sm outline-none focus:border-primary/60"
										name="chapter_role"
										value={chapter.role}
										placeholder="role"
										required
									/>
									<textarea
										class="min-h-24 rounded-lg border border-input bg-background/70 px-3 py-2 text-sm leading-6 outline-none focus:border-primary/60"
										name="chapter_task"
										placeholder="task"
										required
									>{chapter.task}</textarea>
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
					<div class="rounded-xl border border-dashed border-border px-4 py-6 text-sm text-muted-foreground">
						当前人物没有章节，暂时无法编辑。
					</div>
				{/if}
			</form>
		</div>
	</div>
</section>
