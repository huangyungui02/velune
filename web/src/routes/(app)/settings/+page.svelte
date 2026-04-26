<script lang="ts">
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
</script>

<svelte:head>
	<title>Velune · 设置</title>
</svelte:head>

<section class="space-y-6">
	<header class="space-y-2">
		<h1 class="text-2xl leading-tight text-primary">设置</h1>
		<p class="text-sm text-muted-foreground">当前账号：{data.user?.email ?? '未知用户'}</p>
	</header>

	<form method="POST">
		<button
			class="h-11 rounded-xl border border-destructive/40 bg-destructive/10 px-4 text-sm font-medium text-destructive transition hover:bg-destructive/15"
		>
			退出登录
		</button>
	</form>
</section>
