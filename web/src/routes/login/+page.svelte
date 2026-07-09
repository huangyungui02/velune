<script lang="ts">
  import { enhance } from '$app/forms';
  import { resolve } from '$app/paths';
  import * as Alert from '$lib/components/ui/alert';
  import { Button } from '$lib/components/ui/button';
  import * as Card from '$lib/components/ui/card';
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

<main class="relative min-h-screen overflow-hidden bg-background text-foreground">
  <img
    class="absolute inset-0 size-full object-cover object-center opacity-35"
    src="/folio/hero.jpg"
    alt=""
  />
  <div class="absolute inset-0 bg-background/72 backdrop-blur-[2px]"></div>

  <header class="relative flex h-20 items-center justify-between px-5 sm:px-10">
    <Button variant="ghost" href={resolve('/')} aria-label="返回首页">
      <ArrowLeft data-icon="inline-start" />
      返回
    </Button>
    <ThemeToggle />
  </header>

  <section class="relative flex min-h-[calc(100vh-5rem)] items-center justify-center px-4 pb-16">
    <Card.Root class="w-full max-w-md bg-card/94 shadow-xl backdrop-blur-md">
      <Card.Header class="items-center text-center">
        <div
          class="mb-2 flex size-12 items-center justify-center rounded-full bg-primary text-primary-foreground"
        >
          <Feather />
        </div>
        <Card.Title class="font-serif text-3xl">
          {isRegister ? '开始一段漫步' : '欢迎回来'}
        </Card.Title>
        <Card.Description>
          {isRegister ? '以文字为舟，去往思想更深处。' : '回到你的阅读与思考之中。'}
        </Card.Description>
      </Card.Header>

      <Card.Content>
        <div class="mb-6 grid grid-cols-2 rounded-lg bg-muted p-1">
          <Button
            href={resolve('/login')}
            variant={isRegister ? 'ghost' : 'secondary'}
            aria-current={!isRegister ? 'page' : undefined}
          >
            登录
          </Button>
          <Button
            href={resolve('/login?mode=register')}
            variant={isRegister ? 'secondary' : 'ghost'}
            aria-current={isRegister ? 'page' : undefined}
          >
            注册
          </Button>
        </div>

        {#if form?.message}
          <Alert.Root variant="destructive" class="mb-5">
            <CircleX />
            <Alert.Title>无法继续</Alert.Title>
            <Alert.Description>{form.message}</Alert.Description>
          </Alert.Root>
        {/if}

        <form
          method="POST"
          action={isRegister ? '?/register&mode=register' : '?/login'}
          use:enhance={handleSubmit}
        >
          <Field.FieldGroup>
            <Field.Field data-invalid={form?.message ? true : undefined}>
              <Field.FieldLabel for="email">邮箱</Field.FieldLabel>
              <Input
                id="email"
                name="email"
                type="email"
                autocomplete="email"
                placeholder="you@example.com"
                value={form?.email ?? ''}
                required
                aria-invalid={form?.message ? true : undefined}
              />
            </Field.Field>

            <Field.Field data-invalid={form?.message ? true : undefined}>
              <Field.FieldLabel for="password">密码</Field.FieldLabel>
              <Input
                id="password"
                name="password"
                type="password"
                autocomplete={isRegister ? 'new-password' : 'current-password'}
                placeholder={isRegister ? '至少 6 位' : '输入密码'}
                minlength={6}
                required
                aria-invalid={form?.message ? true : undefined}
              />
              {#if isRegister}
                <Field.FieldDescription>使用至少 6 位字符。</Field.FieldDescription>
              {/if}
            </Field.Field>

            <Button type="submit" size="lg" disabled={submitting}>
              {#if submitting}
                <Spinner data-icon="inline-start" />
              {/if}
              {submitting ? '请稍候' : isRegister ? '创建账号' : '登录'}
            </Button>
          </Field.FieldGroup>
        </form>
      </Card.Content>

      <Card.Footer class="justify-center">
        <p class="text-center text-xs leading-5 text-muted-foreground">
          {isRegister ? '注册即表示你同意妥善保管自己的账号信息。' : '使用你的邮箱与密码继续。'}
        </p>
      </Card.Footer>
    </Card.Root>
  </section>
</main>
