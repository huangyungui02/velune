<script lang="ts">
	import { Badge } from '$lib/components/ui/badge/index.js';
	import { Button } from '$lib/components/ui/button/index.js';
	import * as Card from '$lib/components/ui/card/index.js';
	import { Input } from '$lib/components/ui/input/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import { Textarea } from '$lib/components/ui/textarea/index.js';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();

	const backHref = $derived(`/admin?tab=${data.tab}`);
	const wikidataUrl = $derived(
		data.souler.wikidata
			? `https://www.wikidata.org/wiki/${encodeURIComponent(data.souler.wikidata)}`
			: ''
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
		<Button href={backHref} variant="ghost" size="sm" class="h-7 px-0 text-muted-foreground"
			>返回列表</Button
		>
		<h1 class="text-2xl leading-tight text-primary">编辑人物</h1>
		<p class="text-sm text-muted-foreground">
			{data.souler.canonicalName || '暂无 canonical name'}
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

	<div class="grid gap-5 lg:grid-cols-[12rem_1fr]">
		<Card.Root class="space-y-3 rounded-2xl bg-background/52 p-3 py-3 ring-1 ring-border/68">
			<div
				class="relative aspect-[3/4] overflow-hidden rounded-xl bg-muted/30 ring-1 ring-border/70"
			>
				{#if data.souler.imageUrl}
					<img
						src={data.souler.imageUrl}
						alt={data.souler.name}
						class="h-full w-full object-cover"
					/>
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
				<Button
					variant="outline"
					size="sm"
					type="submit"
					class="h-9 rounded-xl border-primary/25 bg-primary/10 text-primary hover:bg-primary/15"
					formaction="?/uploadAvatar"
				>
					上传头像
				</Button>
			</form>
		</Card.Root>

		<div class="space-y-4">
			<Card.Root class="rounded-2xl bg-background/52 py-4 ring-1 ring-border/70">
				<Card.Content class="grid gap-3 px-4">
					<form method="POST" class="grid gap-3">
						<input type="hidden" name="souler_id" value={data.souler.id} />
						<input type="hidden" name="lang" value={data.souler.lang} />
						<input type="hidden" name="tab" value={data.tab} />

						<div class="grid gap-3 md:grid-cols-[1fr_auto]">
							<label class="grid gap-1.5">
								<span class="text-xs text-muted-foreground">人物名</span>
								<Input
									class="h-10 rounded-xl bg-background/72 text-sm"
									name="name"
									value={data.souler.name}
									required
								/>
							</label>

							<label
								class="grid h-10 self-end rounded-xl border border-border/70 bg-card/80 px-3 text-sm"
							>
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
							<Input
								class="h-10 rounded-xl bg-background/72 text-sm"
								name="wikidata"
								value={data.souler.wikidata}
								placeholder="例如：Q937"
							/>
						</label>

						{#if wikidataUrl}
							<Button
								href={wikidataUrl}
								target="_blank"
								rel="noreferrer"
								variant="link"
								size="sm"
								class="h-auto w-fit px-0 text-xs"
							>
								打开 Wikidata 条目
							</Button>
						{/if}

						<label class="grid gap-1.5">
							<span class="text-xs text-muted-foreground">简介</span>
							<Textarea
								class="min-h-28 rounded-xl bg-background/72 text-sm leading-6"
								name="bio"
								value={data.souler.bio}
							/>
						</label>

						<div class="space-y-2">
							<p class="text-xs text-muted-foreground">关键词与权重</p>
							<div class="grid gap-2">
								{#each keywordRows as row, index (`${row.word}-${index}`)}
									<div class="grid grid-cols-[1fr_8rem] gap-2">
										<Input
											class="h-9 rounded-lg bg-background/72 text-sm"
											name="keyword_word"
											value={row.word}
											placeholder="关键词"
										/>
										<Input
											type="number"
											name="keyword_weight"
											min="0"
											max="1"
											step="0.01"
											class="h-9 rounded-lg bg-background/72 text-sm"
											value={row.weight}
										/>
									</div>
								{/each}
							</div>
						</div>

						<Button
							class="h-10 rounded-xl px-4 text-sm font-medium"
							type="submit"
							formaction="?/saveSouler">保存人物信息</Button
						>
					</form>
				</Card.Content>
			</Card.Root>

			<Card.Root class="rounded-2xl bg-background/52 py-4 ring-1 ring-border/70">
				<Card.Content class="space-y-3 px-4">
					<form method="POST" class="space-y-3">
						<input type="hidden" name="souler_id" value={data.souler.id} />
						<input type="hidden" name="tab" value={data.tab} />

						<div class="flex items-center justify-between">
							<h3 class="text-xl text-primary">章节</h3>
							<Badge variant="outline" class="text-[0.68rem]"
								>{data.souler.chapters.length} 条</Badge
							>
						</div>

						{#if data.souler.chapters.length > 0}
							<div class="grid gap-3">
								{#each data.souler.chapters as chapter (chapter.id)}
									<Card.Root class="rounded-xl bg-card/75 py-3 ring-1 ring-border/70" size="sm">
										<Card.Content class="grid gap-2 px-3">
											<input type="hidden" name="chapter_id" value={chapter.id} />
											<p class="text-xs text-muted-foreground">第 {chapter.seq} 章</p>
											<Input
												class="h-9 rounded-lg bg-background/72 text-sm"
												name="chapter_title"
												value={chapter.title}
												placeholder="标题"
												required
											/>
											<Input
												class="h-9 rounded-lg bg-background/72 text-sm"
												name="chapter_subtitle"
												value={chapter.subtitle}
												placeholder="副标题"
												required
											/>
											<Input
												class="h-9 rounded-lg bg-background/72 text-sm"
												name="chapter_role"
												value={chapter.role}
												placeholder="role"
												required
											/>
											<Textarea
												class="min-h-24 rounded-lg bg-background/72 text-sm leading-6"
												name="chapter_task"
												placeholder="task"
												value={chapter.task}
												required
											/>
										</Card.Content>
									</Card.Root>
								{/each}
							</div>

							<Button
								class="h-10 rounded-xl px-4 text-sm font-medium"
								type="submit"
								formaction="?/saveChapters"
							>
								保存章节
							</Button>
						{:else}
							<Card.Root class="rounded-xl border-dashed px-4 py-6 ring-1 ring-border">
								<Card.Content class="p-0 text-sm text-muted-foreground">
									当前人物没有章节，暂时无法编辑。
								</Card.Content>
							</Card.Root>
						{/if}
					</form>
				</Card.Content>
			</Card.Root>

			<Card.Root class="rounded-2xl bg-destructive/5 py-4 ring-1 ring-destructive/25">
				<Card.Content class="space-y-3 px-4">
					<h3 class="text-lg text-destructive">删除人物</h3>
					<p class="text-sm text-muted-foreground">
						删除后会级联清理 resonances、chapters、sessions、messages、souler_status、souler_keyword、souler_aliases 等关联数据。
					</p>
					<form
						method="POST"
						class="w-fit"
						onsubmit={(event) => {
							if (!confirm('确认删除该人物吗？此操作不可撤销。')) {
								event.preventDefault();
							}
						}}
					>
						<input type="hidden" name="souler_id" value={data.souler.id} />
						<input type="hidden" name="tab" value={data.tab} />
						<Button
							type="submit"
							formaction="?/deleteSouler"
							variant="outline"
							class="h-10 rounded-xl border-destructive/35 bg-destructive/10 px-4 text-sm text-destructive hover:bg-destructive/15"
						>
							删除 Souler
						</Button>
					</form>
				</Card.Content>
			</Card.Root>
		</div>
	</div>
</section>
