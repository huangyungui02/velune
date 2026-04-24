<script lang="ts">
	import type { PageProps } from './$types';

	let { form }: PageProps = $props();
</script>

<svelte:head>
	<title>Velune · 登录</title>
</svelte:head>

<main class="mx-auto grid min-h-dvh w-full max-w-6xl place-items-center p-6">
	<section
		class="w-full max-w-md rounded-3xl border border-border/60 bg-card/90 p-7 shadow-[0_18px_40px_-28px_oklch(0.2_0.02_40_/_35%)] backdrop-blur-sm"
	>
		<header class="space-y-2">
			<p class="font-hand text-3xl text-primary">Velune</p>
			<h1 class="text-xl font-semibold">进入你的书架</h1>
			<p class="text-sm text-muted-foreground">用邮箱密码注册或登录</p>
		</header>

		<form method="POST" class="mt-6 space-y-4">
			<label class="grid gap-1.5">
				<span class="text-sm text-muted-foreground">邮箱</span>
				<input
					class="h-11 rounded-xl border border-input bg-background/70 px-3 text-sm transition outline-none focus:border-primary/60"
					type="email"
					name="email"
					placeholder="you@example.com"
					value={form?.email ?? ''}
					required
				/>
			</label>

			<label class="grid gap-1.5">
				<span class="text-sm text-muted-foreground">密码</span>
				<input
					class="h-11 rounded-xl border border-input bg-background/70 px-3 text-sm transition outline-none focus:border-primary/60"
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
				<button
					class="h-11 rounded-xl border border-primary/20 bg-primary/10 px-3 text-sm font-medium text-primary transition hover:bg-primary/15"
					formaction="?/signup"
				>
					注册
				</button>
				<button
					class="h-11 rounded-xl border border-primary/30 bg-primary px-3 text-sm font-medium text-primary-foreground transition hover:opacity-90"
					formaction="?/login"
				>
					登录
				</button>
			</div>
		</form>
	</section>
</main>
