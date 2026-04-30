<script lang="ts">
	import { Badge } from '$lib/components/ui/badge/index.js';
	import { Button } from '$lib/components/ui/button/index.js';
	import * as Card from '$lib/components/ui/card/index.js';
	import { Input } from '$lib/components/ui/input/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import { Textarea } from '$lib/components/ui/textarea/index.js';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();
	const backHref = $derived('/admin?tab=sections');
</script>

<section class="space-y-5">
	<header class="space-y-2">
		<Button href={backHref} variant="ghost" size="sm" class="h-7 px-0 text-muted-foreground"
			>返回精选列表</Button
		>
		<h1 class="text-2xl leading-tight text-primary">编辑精选分组</h1>
		<p class="text-sm text-muted-foreground">{data.section.title} · {data.section.lang}</p>
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

	<Card.Root class="rounded-2xl bg-background/52 py-4 ring-1 ring-border/70">
		<Card.Content class="grid gap-3 px-4">
			<form method="POST" class="grid gap-3">
				<input type="hidden" name="section_id" value={data.section.id} />
				<input type="hidden" name="tab" value="sections" />

				<div class="grid gap-3 md:grid-cols-2">
					<label class="grid gap-1.5">
						<span class="text-xs text-muted-foreground">语言</span>
						<select
							name="lang"
							class="h-10 rounded-xl border border-input bg-background/72 px-3 text-sm outline-none focus:border-primary/60"
						>
							<option value="zh" selected={data.section.lang === 'zh'}>zh</option>
							<option value="en" selected={data.section.lang === 'en'}>en</option>
							<option value="ja" selected={data.section.lang === 'ja'}>ja</option>
						</select>
					</label>

					<label class="grid gap-1.5">
						<span class="text-xs text-muted-foreground">排序</span>
						<Input
							type="number"
							name="sort_order"
							class="h-10 rounded-xl bg-background/72 text-sm"
							value={data.section.sortOrder}
						/>
					</label>
				</div>

				<label class="grid gap-1.5">
					<span class="text-xs text-muted-foreground">标题</span>
					<Input
						class="h-10 rounded-xl bg-background/72 text-sm"
						name="title"
						value={data.section.title}
						required
					/>
				</label>

				<label class="grid gap-1.5">
					<span class="text-xs text-muted-foreground">副标题</span>
					<Textarea
						class="min-h-20 rounded-xl bg-background/72 text-sm leading-6"
						name="subtitle"
						value={data.section.subtitle}
					/>
				</label>

				<label class="grid h-10 w-fit rounded-xl border border-border/70 bg-card/80 px-3 text-sm">
					<span class="inline-flex h-full items-center gap-2">
						<input
							type="checkbox"
							name="is_active"
							checked={data.section.isActive}
							class="size-4 rounded border-border"
						/>
						启用该分组
					</span>
				</label>

				<Button
					class="h-10 rounded-xl px-4 text-sm font-medium"
					type="submit"
					formaction="?/saveSection">保存分组信息</Button
				>
			</form>
		</Card.Content>
	</Card.Root>

	<Card.Root class="rounded-2xl bg-background/52 py-4 ring-1 ring-border/70">
		<Card.Content class="space-y-3 px-4">
			<div class="flex items-center justify-between">
				<h2 class="text-xl text-primary">分组人物</h2>
				<Badge variant="outline" class="text-[0.68rem]">{data.section.items.length} 人</Badge>
			</div>

			{#if data.section.items.length > 0}
				<form method="POST" class="space-y-3">
					<input type="hidden" name="section_id" value={data.section.id} />
					<input type="hidden" name="tab" value="sections" />
					<div class="grid gap-3">
						{#each data.section.items as item (item.soulerId)}
							<Card.Root class="rounded-xl bg-card/75 py-3 ring-1 ring-border/70" size="sm">
								<Card.Content class="grid grid-cols-[4rem_1fr] gap-3 px-3">
									<div
										class="relative aspect-[3/4] overflow-hidden rounded-lg bg-muted/30 ring-1 ring-border/65"
									>
										{#if item.imageUrl}
											<img
												src={item.imageUrl}
												alt={item.soulerName}
												class="h-full w-full object-cover"
											/>
										{:else}
											<div class="grid h-full place-items-center text-[10px] text-muted-foreground">
												无图
											</div>
										{/if}
									</div>
									<div class="space-y-2">
										<input type="hidden" name="item_souler_id" value={item.soulerId} />
										<p class="line-clamp-1 text-sm">{item.soulerName}</p>
										<div class="grid gap-2 md:grid-cols-[8rem_auto]">
											<label class="grid gap-1">
												<span class="text-[11px] text-muted-foreground">排序</span>
												<Input
													type="number"
													name="item_sort_order"
													class="h-8 rounded-lg bg-background/72 text-xs"
													value={item.sortOrder}
												/>
											</label>
											<label
												class="inline-flex h-8 items-center gap-2 self-end text-xs text-muted-foreground"
											>
												<input
													type="checkbox"
													name="remove_souler_id"
													value={item.soulerId}
													class="size-4 rounded border-border"
												/>
												标记移除
											</label>
										</div>
									</div>
								</Card.Content>
							</Card.Root>
						{/each}
					</div>
					<Button
						class="h-10 rounded-xl px-4 text-sm font-medium"
						type="submit"
						formaction="?/saveItems"
					>
						保存排序与移除
					</Button>
				</form>
			{:else}
				<Card.Root class="rounded-xl border-dashed px-4 py-6 ring-1 ring-border">
					<Card.Content class="p-0 text-sm text-muted-foreground">
						当前分组暂无人物，请先从下方加入。
					</Card.Content>
				</Card.Root>
			{/if}
		</Card.Content>
	</Card.Root>

	<Card.Root class="rounded-2xl bg-background/52 py-4 ring-1 ring-border/70">
		<Card.Content class="space-y-3 px-4">
			<h2 class="text-xl text-primary">加入人物</h2>
			{#if data.section.availableSoulers.length > 0}
				<form method="POST" class="grid gap-3 md:grid-cols-[1fr_auto]">
					<input type="hidden" name="section_id" value={data.section.id} />
					<input type="hidden" name="tab" value="sections" />
					<select
						name="souler_id"
						class="h-10 rounded-xl border border-input bg-background/72 px-3 text-sm outline-none focus:border-primary/60"
					>
						{#each data.section.availableSoulers as souler (souler.id)}
							<option value={souler.id}>{souler.name} · {souler.lang}</option>
						{/each}
					</select>
					<Button type="submit" class="h-10 rounded-xl px-4 text-sm" formaction="?/addItem">
						加入分组
					</Button>
				</form>
			{:else}
				<p class="text-sm text-muted-foreground">该语言下没有可加入的已审核人物。</p>
			{/if}
		</Card.Content>
	</Card.Root>

	<Card.Root class="rounded-2xl bg-destructive/5 py-4 ring-1 ring-destructive/25">
		<Card.Content class="space-y-3 px-4">
			<h3 class="text-lg text-destructive">删除分组</h3>
			<p class="text-sm text-muted-foreground">删除后会同时移除该分组下的全部关联人物。</p>
			<form
				method="POST"
				class="w-fit"
				onsubmit={(event) => {
					if (!confirm('确认删除该分组吗？此操作不可撤销。')) {
						event.preventDefault();
					}
				}}
			>
				<input type="hidden" name="section_id" value={data.section.id} />
				<input type="hidden" name="tab" value="sections" />
				<Button
					type="submit"
					formaction="?/deleteSection"
					variant="outline"
					class="h-10 rounded-xl border-destructive/35 bg-destructive/10 px-4 text-sm text-destructive hover:bg-destructive/15"
				>
					删除分组
				</Button>
			</form>
		</Card.Content>
	</Card.Root>
</section>
