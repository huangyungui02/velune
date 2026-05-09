<script lang="ts">
	import ChevronRight from '@lucide/svelte/icons/chevron-right';
	import Feather from '@lucide/svelte/icons/feather';
	import LogOut from '@lucide/svelte/icons/log-out';
	import MessageCircle from '@lucide/svelte/icons/message-circle';
	import Trash2 from '@lucide/svelte/icons/trash-2';
	import DeleteAccountAlert from '$lib/components/app/DeleteAccountAlert.svelte';
	import { Button } from '$lib/components/ui/button/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import { aiReplyPreference } from '$lib/stores/ai-reply-preference.svelte';
	import type { AiReplyLength } from '$lib/types';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	const email = $derived(data.user?.email ?? '未知用户');
	const emailInitial = $derived((email.trim().charAt(0) || 'V').toUpperCase());
	const developerContactUrl = 'https://xhslink.com/m/6RghZ8ot2N0';
	const replyLengthOptions: { value: AiReplyLength; label: string }[] = [
		{ value: 'standard', label: '标准' },
		{ value: 'concise', label: '简洁' }
	];
</script>

<svelte:head>
	<title>Velune Folio · 我的</title>
</svelte:head>

<section class="mx-auto flex min-h-[72dvh] w-full max-w-xl flex-col">
	<header class="space-y-2">
		<h1 class="text-2xl leading-tight text-primary">我的</h1>
		<Separator class="mt-3" />
	</header>

	<div class="mt-6 space-y-4">
		<article class="rounded-2xl border border-border/50 bg-background/75 px-4 py-4">
			<div class="flex items-center gap-3">
				<div
					class="grid size-11 shrink-0 place-items-center rounded-full bg-primary/10 text-base font-medium text-primary"
				>
					{emailInitial}
				</div>
				<div class="min-w-0 flex-1">
					<p class="truncate text-sm text-foreground">{email}</p>
				</div>
			</div>
		</article>

		<article class="rounded-2xl border border-border/45 bg-background/80 px-4 py-3.5">
			<div class="flex items-center gap-3">
				<div
					class="grid size-10 shrink-0 place-items-center rounded-full bg-primary/10 text-primary"
				>
					<Feather class="size-4" />
				</div>
				<div class="min-w-0 flex-1">
					<p class="text-sm text-foreground">AI 回复长度</p>
				</div>
				<div class="grid grid-cols-2 rounded-full border border-border/60 bg-muted/35 p-0.5">
					{#each replyLengthOptions as option (option.value)}
						<button
							type="button"
							class={[
								'h-8 min-w-14 rounded-full px-3 text-sm transition-colors',
								aiReplyPreference.replyLength === option.value
									? 'bg-background text-foreground shadow-xs'
									: 'text-muted-foreground hover:text-foreground'
							]}
							aria-pressed={aiReplyPreference.replyLength === option.value}
							onclick={() => aiReplyPreference.setReplyLength(option.value)}
						>
							{option.label}
						</button>
					{/each}
				</div>
			</div>
		</article>

		<a
			href={developerContactUrl}
			target="_blank"
			rel="noreferrer"
			class="group flex items-center gap-3 rounded-2xl border border-border/45 bg-background/80 px-4 py-3.5 transition hover:bg-muted/30"
		>
			<div
				class="grid size-10 shrink-0 place-items-center rounded-full bg-rose-500/12 text-rose-600"
			>
				<MessageCircle class="size-4" />
			</div>
			<div class="min-w-0 flex-1">
				<p class="text-sm text-foreground">联系开发者</p>
			</div>
			<ChevronRight
				class="size-4 text-muted-foreground/70 transition group-hover:translate-x-0.5 group-hover:text-foreground/80"
			/>
		</a>

		<DeleteAccountAlert
			triggerClass="h-auto w-full justify-start gap-3 rounded-2xl border border-border/45 bg-background/80 px-4 py-3.5 text-destructive hover:bg-destructive/10 hover:text-destructive"
		>
			<div
				class="grid size-10 shrink-0 place-items-center rounded-full bg-destructive/10 text-destructive"
			>
				<Trash2 class="size-4" />
			</div>
			<div class="min-w-0 flex-1 text-left">
				<p class="text-sm">注销账号</p>
			</div>
			<ChevronRight class="size-4 text-destructive/60" />
		</DeleteAccountAlert>
	</div>

	<div class="mt-auto pt-8">
		<form method="POST">
			<Button
				type="submit"
				variant="ghost"
				size="sm"
				class="h-11 w-full gap-2 rounded-2xl text-destructive hover:bg-destructive/10 hover:text-destructive"
			>
				<LogOut class="size-4" />
				退出登录
			</Button>
		</form>
	</div>
</section>
