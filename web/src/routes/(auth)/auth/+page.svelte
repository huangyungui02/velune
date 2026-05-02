<script lang="ts">
	import { Button } from '$lib/components/ui/button/index.js';
	import * as Card from '$lib/components/ui/card/index.js';
	import { Input } from '$lib/components/ui/input/index.js';
	import * as Tabs from '$lib/components/ui/tabs/index.js';
	import type { PageProps } from './$types';

	let { form }: PageProps = $props();
	let activeTab = $state<'login' | 'signup'>('login');
	let serverTab = $derived<'login' | 'signup' | null>(
		form?.mode === 'login' || form?.mode === 'signup' ? form.mode : null
	);
</script>

<svelte:head>
	<title>Velune Folio · 登录</title>
</svelte:head>

<main class="mx-auto grid min-h-dvh w-full max-w-6xl place-items-center p-6">
	<Card.Root
		class="w-full max-w-md rounded-3xl bg-card/88 py-7 shadow-[0_18px_40px_-28px_oklch(0.2_0.02_40_/_35%)] ring-1 ring-border/65 backdrop-blur-sm"
	>
		<Card.Header class="space-y-2 px-7">
			<p class="font-serif text-2xl text-primary">Velune Folio</p>
			<Card.Description class="text-sm">用邮箱密码注册或登录</Card.Description>
		</Card.Header>

		<Card.Content class="px-7 pt-2">
			<Tabs.Root
				value={serverTab ?? activeTab}
				onValueChange={(value) => {
					activeTab = value as 'login' | 'signup';
				}}
				class="w-full"
			>
				<Tabs.List class="grid w-full grid-cols-2 rounded-xl bg-muted/70 p-1">
					<Tabs.Trigger value="login" class="rounded-lg text-sm">登录</Tabs.Trigger>
					<Tabs.Trigger value="signup" class="rounded-lg text-sm">注册</Tabs.Trigger>
				</Tabs.List>

				<Tabs.Content value="login" class="mt-4">
					<form method="POST" action="?/login" class="space-y-4">
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

						{#if form?.message && (form?.mode === 'login' || !form?.mode)}
							<p class="rounded-xl bg-accent/35 px-3 py-2 text-sm">{form.message}</p>
						{/if}

						<Button class="h-11 w-full rounded-xl text-sm font-medium" type="submit">登录</Button>
					</form>
				</Tabs.Content>

				<Tabs.Content value="signup" class="mt-4">
					<form method="POST" action="?/signup" class="space-y-4">
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

						<label class="grid gap-1.5">
							<span class="text-sm text-muted-foreground">重复密码</span>
							<Input
								class="h-11 rounded-xl bg-background/70 text-sm"
								type="password"
								name="passwordConfirm"
								placeholder="再次输入密码"
								minlength={6}
								required
							/>
						</label>

						{#if form?.message && form?.mode === 'signup'}
							<p class="rounded-xl bg-accent/35 px-3 py-2 text-sm">{form.message}</p>
						{/if}

						<Button class="h-11 w-full rounded-xl text-sm font-medium" type="submit">注册</Button>
					</form>
				</Tabs.Content>
			</Tabs.Root>
		</Card.Content>
	</Card.Root>
</main>
