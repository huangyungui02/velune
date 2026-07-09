<script lang="ts">
  import { enhance } from '$app/forms';
  import { resolve } from '$app/paths';
  import * as Alert from '$lib/components/ui/alert';
  import { Button } from '$lib/components/ui/button';
  import * as Field from '$lib/components/ui/field';
  import { Input } from '$lib/components/ui/input';
  import { Spinner } from '$lib/components/ui/spinner';
  import ThemeToggle from '$lib/components/theme-toggle.svelte';
  import ArrowLeft from '@lucide/svelte/icons/arrow-left';
  import CircleX from '@lucide/svelte/icons/circle-x';
  import Feather from '@lucide/svelte/icons/feather';
  import type { SubmitFunction } from '@sveltejs/kit';
  import type { PageProps } from './$types';

  let { data, form }: PageProps = $props();
  let submitting = $state(false);
  const isRegister = $derived(data.mode === 'register');

  const handleSubmit: SubmitFunction = () => {
    submitting = true;

    return async ({ update }) => {
      await update();
      submitting = false;
    };
  };
</script>

<svelte:head>
  <title>{isRegister ? '注册' : '登录'} | Folio</title>
  <meta name="description" content="登录 Folio，继续你的思想漫步。" />
</svelte:head>

<main
  class="grid min-h-screen grid-cols-1 lg:grid-cols-12 bg-background text-foreground overflow-hidden"
>
  <!-- 左侧表单区域 -->
  <div
    class="col-span-1 lg:col-span-5 flex flex-col justify-between p-6 sm:p-10 md:p-12 lg:p-16 relative z-10 bg-background border-r border-border/40"
  >
    <!-- 顶部导航 -->
    <header class="flex h-12 items-center justify-between">
      <Button
        variant="ghost"
        href={resolve('/')}
        aria-label="返回首页"
        class="rounded-full px-4 hover:bg-muted/60 transition-colors"
      >
        <ArrowLeft class="size-4 mr-2" />
        返回首页
      </Button>
      <ThemeToggle />
    </header>

    <!-- 主表单容器 -->
    <div class="mx-auto w-full max-w-sm py-8 sm:py-12 flex-1 flex flex-col justify-center">
      <div class="mb-8 flex flex-col items-start animate-fade-in">
        <div
          class="mb-4 flex size-11 items-center justify-center rounded-full bg-primary/10 text-primary"
        >
          <Feather class="size-5" />
        </div>
        <h1 class="font-serif text-3xl font-medium tracking-tight text-foreground">
          {isRegister ? '开始一段漫步' : '欢迎回来'}
        </h1>
        <p class="mt-2 text-sm text-muted-foreground leading-relaxed">
          {isRegister ? '以文字为舟，去往思想更深处。' : '回到你的阅读与思考之中。'}
        </p>
      </div>

      <!-- 登录/注册选项卡 -->
      <div class="mb-6 grid grid-cols-2 rounded-lg bg-muted/50 p-1 border border-border/30">
        <Button
          href={resolve('/login')}
          variant="ghost"
          class={[
            'rounded-md font-sans text-xs sm:text-sm h-9 transition-all',
            !isRegister
              ? 'bg-background text-foreground shadow-xs border border-border/40 font-medium hover:bg-background'
              : 'text-muted-foreground hover:text-foreground hover:bg-transparent'
          ]}
          aria-current={!isRegister ? 'page' : undefined}
        >
          登录
        </Button>
        <Button
          href={resolve('/login?mode=register')}
          variant="ghost"
          class={[
            'rounded-md font-sans text-xs sm:text-sm h-9 transition-all',
            isRegister
              ? 'bg-background text-foreground shadow-xs border border-border/40 font-medium hover:bg-background'
              : 'text-muted-foreground hover:text-foreground hover:bg-transparent'
          ]}
          aria-current={isRegister ? 'page' : undefined}
        >
          注册
        </Button>
      </div>

      {#if form?.message}
        <Alert.Root
          variant="destructive"
          class="mb-5 border-destructive/20 bg-destructive/5 rounded-xl"
        >
          <CircleX class="size-4 text-destructive" />
          <Alert.Title class="text-sm font-medium">无法继续</Alert.Title>
          <Alert.Description class="text-xs text-destructive/90">{form.message}</Alert.Description>
        </Alert.Root>
      {/if}

      <form
        method="POST"
        action={isRegister
          ? `?/register&mode=register`
          : `?/login&redirectTo=${encodeURIComponent(data.redirectTo)}`}
        use:enhance={handleSubmit}
        class="space-y-4"
      >
        <Field.FieldGroup class="space-y-4">
          <Field.Field data-invalid={form?.message ? true : undefined} class="space-y-1.5">
            <Field.FieldLabel for="email" class="text-xs font-medium text-muted-foreground/80"
              >邮箱</Field.FieldLabel
            >
            <Input
              id="email"
              name="email"
              type="email"
              autocomplete="email"
              placeholder="you@example.com"
              value={form?.email ?? ''}
              required
              class="h-10 border-border/50 bg-background/50 px-3 text-sm focus-visible:ring-1 focus-visible:ring-primary focus-visible:border-primary rounded-lg"
              aria-invalid={form?.message ? true : undefined}
            />
          </Field.Field>

          <Field.Field data-invalid={form?.message ? true : undefined} class="space-y-1.5">
            <div class="flex items-center justify-between">
              <Field.FieldLabel for="password" class="text-xs font-medium text-muted-foreground/80"
                >密码</Field.FieldLabel
              >
            </div>
            <Input
              id="password"
              name="password"
              type="password"
              autocomplete={isRegister ? 'new-password' : 'current-password'}
              placeholder={isRegister ? '至少 6 位' : '输入密码'}
              minlength={6}
              required
              class="h-10 border-border/50 bg-background/50 px-3 text-sm focus-visible:ring-1 focus-visible:ring-primary focus-visible:border-primary rounded-lg"
              aria-invalid={form?.message ? true : undefined}
            />
            {#if isRegister}
              <Field.FieldDescription class="text-[11px] text-muted-foreground/70"
                >使用至少 6 位字符。</Field.FieldDescription
              >
            {/if}
          </Field.Field>

          <Button
            type="submit"
            size="lg"
            disabled={submitting}
            class="w-full mt-3 h-10 bg-primary hover:bg-primary/90 text-primary-foreground font-sans tracking-wide rounded-lg transition-all shadow-sm"
          >
            {#if submitting}
              <Spinner data-icon="inline-start" class="size-4 animate-spin mr-2" />
            {/if}
            {submitting ? '请稍候' : isRegister ? '创建账号' : '登录'}
          </Button>
        </Field.FieldGroup>
      </form>
    </div>

    <!-- 底部辅助说明 -->
    <footer class="text-center text-[11px] text-muted-foreground/60 leading-5">
      {isRegister ? '注册即表示你同意妥善保管自己的账号信息。' : '使用你的邮箱与密码继续。'}
    </footer>
  </div>

  <!-- 右侧唯美大图区域 (只在 lg 屏幕及以上显示) -->
  <div
    class="hidden lg:flex lg:col-span-7 relative overflow-hidden bg-background flex-col justify-end p-16"
  >
    <!-- 背景插图，带微妙缩放动画 -->
    <img
      class="absolute inset-0 size-full object-cover object-center transition-transform duration-10000 ease-out hover:scale-105"
      src="/folio/hero.jpg"
      alt="唯美山海之门"
    />
    <!-- 渐变层和暗化叠加，保证文字可读性，仅在底部渐变 -->
    <div class="absolute inset-0 bg-gradient-to-t from-black/60 via-black/10 to-transparent"></div>

    <!-- 名言卡片容器 -->
    <div
      class="relative z-10 max-w-xl rounded-2xl border border-white/10 bg-black/20 p-8 text-white backdrop-blur-md shadow-2xl transition-all duration-500 hover:border-white/20"
    >
      <div class="relative min-h-[5.5rem] flex flex-col justify-between">
        {#if !isRegister}
          <p class="font-serif text-2xl leading-loose tracking-wide text-zinc-100 font-light">
            “在荒诞中寻找清醒的自由。”
          </p>
          <p class="mt-4 font-serif text-sm text-zinc-300/80 text-right italic">—— 阿尔贝·加缪</p>
        {:else}
          <p class="font-serif text-2xl leading-loose tracking-wide text-zinc-100 font-light">
            “以文字为舟，去往思想更深处。”
          </p>
          <p class="mt-4 font-serif text-sm text-zinc-300/80 text-right italic">
            —— 拉宾德拉纳特·泰戈尔
          </p>
        {/if}
      </div>
    </div>
  </div>
</main>
