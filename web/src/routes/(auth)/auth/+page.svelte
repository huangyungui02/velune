<script lang="ts">
	import { Button } from '$lib/components/ui/button/index.js';
	import * as Card from '$lib/components/ui/card/index.js';
	import { Input } from '$lib/components/ui/input/index.js';
	import type { PageProps } from './$types';

	let { form }: PageProps = $props();
</script>

<svelte:head>
	<title>Velune · 登录</title>
</svelte:head>

<main class="mx-auto grid min-h-dvh w-full max-w-6xl place-items-center p-6">
	<Card.Root
		class="w-full max-w-md rounded-3xl bg-card/88 py-7 shadow-[0_18px_40px_-28px_oklch(0.2_0.02_40_/_35%)] ring-1 ring-border/65 backdrop-blur-sm"
	>
		<Card.Header class="space-y-2 px-7">
			<p class="font-hand text-3xl text-primary">Velune</p>
			<Card.Title class="text-xl font-semibold">进入你的书架</Card.Title>
			<Card.Description class="text-sm">用邮箱密码注册或登录</Card.Description>
		</Card.Header>

		<Card.Content class="px-7 pt-2">
			<form method="POST" class="space-y-4">
				<label class="grid gap-1.5">
					<span class="text-sm text-muted-foreground">邮箱</span>
					<Input
						class="h-11 rounded-xl bg-background/70 text-sm"
						type="email"
						name="email"
						placeholder="you@example.com"
						value={form?.email ?? ''}
						required
					/>
				</label>

				<label class="grid gap-1.5">
					<span class="text-sm text-muted-foreground">密码</span>
					<Input
						class="h-11 rounded-xl bg-background/70 text-sm"
						type="password"
						name="password"
						placeholder="至少 6 位"
						minlength={6}
						required
					/>
				</label>

				{#if form?.message}
					<p class="rounded-xl bg-accent/35 px-3 py-2 text-sm">{form.message}</p>
				{/if}

				<div class="grid grid-cols-2 gap-3 pt-2">
					<Button
						class="h-11 rounded-xl border-primary/20 bg-primary/10 text-sm font-medium text-primary hover:bg-primary/15"
						variant="outline"
						type="submit"
						formaction="?/signup"
					>
						注册
					</Button>
					<Button class="h-11 rounded-xl text-sm font-medium" type="submit" formaction="?/login"
						>登录</Button
					>
				</div>
			</form>
		</Card.Content>
	</Card.Root>
</main>
