<script lang="ts">
	import ChevronRight from '@lucide/svelte/icons/chevron-right';
	import LogOut from '@lucide/svelte/icons/log-out';
	import MessageCircle from '@lucide/svelte/icons/message-circle';
	import { Button } from '$lib/components/ui/button/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	const email = $derived(data.user?.email ?? '未知用户');
	const emailInitial = $derived((email.trim().charAt(0) || 'V').toUpperCase());
	const developerContactUrl = 'https://xhslink.com/m/6RghZ8ot2N0';
</script>

<svelte:head>
	<title>Velune · 我的</title>
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
					<p class="text-xs text-muted-foreground">当前邮箱</p>
					<p class="truncate text-sm text-foreground">{email}</p>
				</div>
				<form method="POST" class="shrink-0">
					<Button
						type="submit"
						variant="ghost"
						size="icon-sm"
						class="text-destructive hover:bg-destructive/10 hover:text-destructive"
						aria-label="退出登录"
						title="退出登录"
					>
						<LogOut class="size-4" />
					</Button>
				</form>
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
				<p class="text-xs text-muted-foreground">问题、反馈、交流等，联系开发者</p>
			</div>
			<ChevronRight
				class="size-4 text-muted-foreground/70 transition group-hover:translate-x-0.5 group-hover:text-foreground/80"
			/>
		</a>
	</div>
</section>
