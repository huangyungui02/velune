<script lang="ts">
  import { Badge } from '$lib/components/ui/badge';
  import { Button } from '$lib/components/ui/button';
  import * as Avatar from '$lib/components/ui/avatar';
  import * as Card from '$lib/components/ui/card';
  import { Separator } from '$lib/components/ui/separator';
  import ThemeToggle from '$lib/components/theme-toggle.svelte';
  import { resolve } from '$app/paths';
  import ArrowRight from '@lucide/svelte/icons/arrow-right';
  import Bookmark from '@lucide/svelte/icons/bookmark';
  import ChevronDown from '@lucide/svelte/icons/chevron-down';
  import Clock from '@lucide/svelte/icons/clock';
  import House from '@lucide/svelte/icons/house';
  import LayoutGrid from '@lucide/svelte/icons/layout-grid';
  import LogOut from '@lucide/svelte/icons/log-out';
  import Menu from '@lucide/svelte/icons/menu';
  import Search from '@lucide/svelte/icons/search';
  import UserRound from '@lucide/svelte/icons/user-round';
  import type { Component } from 'svelte';
  import type { PageProps } from './$types';

  let { data }: PageProps = $props();
  const accountLabel = $derived(data.user?.email || '登录');
  const accountInitial = $derived((data.user?.email?.[0] || 'F').toUpperCase());

  type Icon = Component;

  const navItems: { label: string; icon: Icon; active?: boolean }[] = [
    { label: '漫步', icon: House, active: true },
    { label: '思想家', icon: UserRound },
    { label: '主题', icon: LayoutGrid },
    { label: '书签', icon: Bookmark },
    { label: '继续阅读', icon: Clock }
  ];

  const themes = $derived(data.themes);
  const folios = $derived(data.folios);
  const thinkers = $derived(data.soulers);
</script>

<svelte:head>
  <title>Folio | 思想漫步</title>
  <meta name="description" content="Folio 是一个关于哲学、文学和自我探索的阅读空间。" />
</svelte:head>

<main class="min-h-screen bg-background text-foreground lg:h-screen lg:overflow-hidden">
  <div class="mx-auto flex min-h-screen w-full max-w-[1720px] lg:h-screen">
    <aside
      class="hidden w-64 shrink-0 border-r bg-sidebar/90 px-8 py-10 lg:flex lg:h-screen lg:flex-col lg:overflow-hidden"
    >
      <a class="folio-serif text-4xl font-semibold tracking-normal" href={resolve('/')}>Folio</a>
      <p class="mt-8 max-w-36 text-base leading-8 text-muted-foreground">
        走进思想的世界，遇见另一种可能。
      </p>

      <nav class="mt-12 flex flex-col gap-2">
        {#each navItems as item (item.label)}
          {@const Icon = item.icon}
          <a
            class={[
              'flex h-12 items-center gap-4 rounded-xl px-4 text-[15px] transition-colors',
              item.active
                ? 'bg-sidebar-accent text-sidebar-accent-foreground shadow-sm'
                : 'text-muted-foreground hover:bg-sidebar-accent/70 hover:text-foreground'
            ]}
            href={resolve('/')}
          >
            <Icon strokeWidth={1.7} />
            <span>{item.label}</span>
          </a>
        {/each}
      </nav>

      <Separator class="mt-auto" />
      <div class="mt-5 flex items-center gap-2">
        <Button
          class="min-w-0 flex-1 justify-start px-1"
          variant="ghost"
          href={data.user ? undefined : resolve('/login')}
        >
          <Avatar.Root class="size-10">
            <Avatar.Fallback>{accountInitial}</Avatar.Fallback>
          </Avatar.Root>
          <span class="truncate text-sm font-medium">{accountLabel}</span>
        </Button>
        {#if data.user}
          <form method="POST" action="/auth/signout">
            <Button type="submit" variant="ghost" size="icon-sm" aria-label="退出登录">
              <LogOut />
            </Button>
          </form>
        {/if}
        <ThemeToggle />
      </div>
    </aside>

    <section
      class="min-w-0 flex-1 px-4 py-4 sm:px-6 lg:h-screen lg:overflow-y-auto lg:px-8 lg:py-6"
    >
      <header
        class="mb-4 flex h-14 items-center justify-between rounded-xl border bg-card/80 px-4 backdrop-blur lg:hidden"
      >
        <a class="folio-serif text-3xl font-semibold" href={resolve('/')}>Folio</a>
        <div class="flex items-center gap-2">
          {#if data.user}
            <Avatar.Root class="size-8">
              <Avatar.Fallback>{accountInitial}</Avatar.Fallback>
            </Avatar.Root>
          {:else}
            <Button variant="ghost" size="sm" href={resolve('/login')}>登录</Button>
          {/if}
          <ThemeToggle />
          <Button variant="ghost" size="icon-sm" aria-label="搜索">
            <Search />
          </Button>
          <Button variant="ghost" size="icon-sm" aria-label="打开菜单">
            <Menu />
          </Button>
        </div>
      </header>

      <section
        class="relative overflow-hidden rounded-2xl border border-border/40 bg-card/30 backdrop-blur-xs"
      >
        <img
          class="h-[320px] w-full object-cover object-center sm:h-[380px] lg:h-[430px] transition-transform duration-[10000ms] hover:scale-105 ease-out"
          src="/folio/hero.jpg"
          alt="一道通向远方山海的门"
        />
        <div
          class="absolute inset-0 bg-gradient-to-r from-background/95 via-background/52 to-transparent"
        ></div>
        <div class="absolute left-7 top-1/2 max-w-[420px] -translate-y-1/2 sm:left-14">
          <h1
            class="folio-serif text-6xl font-semibold leading-none tracking-normal sm:text-7xl lg:text-8xl text-foreground"
          >
            Folio
          </h1>
          <p class="mt-6 text-xl leading-9 tracking-normal text-muted-foreground sm:text-2xl">
            走进思想的世界，<br />遇见另一种可能。
          </p>
          <Button
            class="mt-8 rounded-full px-7 bg-primary text-primary-foreground hover:bg-primary/90 transition-all hover:scale-[1.02] shadow-sm"
            size="lg"
          >
            开始探索
            <ArrowRight data-icon="inline-end" />
          </Button>
        </div>
      </section>

      <section class="mt-7">
        <div class="mb-4 flex items-center justify-between gap-4">
          <h2 class="folio-serif text-2xl font-semibold">主题</h2>
        </div>
        <div class="flex gap-3 overflow-x-auto pb-2">
          {#each themes as theme (theme.id)}
            <Button
              variant="secondary"
              class="h-10 shrink-0 rounded-full px-5 border border-border/30 bg-secondary/40 hover:bg-secondary/80 hover:-translate-y-0.5 transition-all duration-300 shadow-xs"
            >
              <span>{theme.label}</span>
            </Button>
          {/each}
          <Button
            variant="outline"
            class="h-10 shrink-0 rounded-full px-5 border border-border/30 hover:-translate-y-0.5 transition-all duration-300 shadow-xs"
          >
            <span>更多</span>
            <ChevronDown data-icon="inline-end" strokeWidth={1.7} />
          </Button>
        </div>
      </section>

      <section class="mt-4">
        <div class="mb-3 flex items-center justify-between">
          <h2 class="folio-serif text-2xl font-semibold">Folio</h2>
          <Button variant="link" href={resolve('/')} class="px-0">
            查看全部
            <ArrowRight data-icon="inline-end" strokeWidth={1.7} />
          </Button>
        </div>

        <div class="grid justify-center gap-5 grid-cols-[repeat(auto-fit,minmax(170px,220px))]">
          {#each folios as folio (folio.id)}
            <Card.Root
              class="group rounded-xl py-0 overflow-hidden border border-border/40 bg-card/60 backdrop-blur-xs hover:-translate-y-1 hover:shadow-md hover:border-border/70 transition-all duration-300"
            >
              <div class="relative aspect-square w-full overflow-hidden bg-muted">
                {#if folio.coverUrl}
                  <img
                    src={folio.coverUrl}
                    alt={folio.title}
                    class="size-full object-cover transition-transform duration-500 group-hover:scale-105"
                  />
                {:else}
                  <div
                    class="flex size-full items-center justify-center bg-secondary/40 px-6 text-center"
                  >
                    <span class="folio-serif text-2xl text-muted-foreground">{folio.title}</span>
                  </div>
                {/if}
                <Button
                  class="absolute right-3 top-3 rounded-full bg-background/75 backdrop-blur hover:bg-background shadow-xs transition-colors"
                  variant="ghost"
                  size="icon-sm"
                  aria-label={`收藏 ${folio.title}`}
                >
                  <Bookmark class="size-4" />
                </Button>
              </div>
              <Card.Content class="pb-5 pt-4">
                <h3 class="folio-serif text-xl font-semibold leading-7">{folio.title}</h3>
                {#if folio.subtitle}
                  <p class="mt-1 line-clamp-2 text-sm leading-5 text-muted-foreground">
                    {folio.subtitle}
                  </p>
                {/if}
                {#if folio.tags.length}
                  <div class="mt-4 flex flex-wrap gap-2">
                    {#each folio.tags as tag (tag)}
                      <Badge
                        variant="secondary"
                        class="rounded-full bg-secondary/50 text-[11px] px-2 py-0.5 border border-border/10"
                        >{tag}</Badge
                      >
                    {/each}
                  </div>
                {/if}
              </Card.Content>
            </Card.Root>
          {/each}
        </div>
      </section>

      <section class="mt-8 pb-8">
        <div class="mb-5 flex items-center justify-between">
          <h2 class="folio-serif text-2xl font-semibold">思想家</h2>
          <Button variant="link" href={resolve('/')} class="px-0">
            查看全部
            <ArrowRight data-icon="inline-end" strokeWidth={1.7} />
          </Button>
        </div>

        <div class="grid gap-x-8 gap-y-10 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
          {#each thinkers as thinker (thinker.id)}
            <a
              class="group block min-w-0 transition-transform duration-300 hover:-translate-y-1"
              href={resolve('/')}
            >
              <div
                class="relative aspect-[3/4] h-40 overflow-hidden rounded-2xl border border-border/50 bg-muted shadow-sm"
              >
                {#if thinker.avatarUrl}
                  <img
                    src={thinker.avatarUrl}
                    alt={thinker.name}
                    class="size-full object-cover grayscale transition-all duration-500 group-hover:scale-105 group-hover:grayscale-0"
                  />
                {:else}
                  <div class="flex size-full items-center justify-center text-2xl text-muted-foreground">
                    {thinker.initials}
                  </div>
                {/if}
              </div>
              <span
                class="mt-4 block text-base font-medium text-foreground transition-colors group-hover:text-primary"
                >{thinker.name}</span
              >
              {#if thinker.keywords.length}
                <span class="mt-3 flex flex-wrap gap-1.5">
                  {#each thinker.keywords as keyword (keyword)}
                    <Badge
                      variant="secondary"
                      class="rounded-full border border-border/10 bg-secondary/50 px-2 py-0.5 text-[11px]"
                      >{keyword}</Badge
                    >
                  {/each}
                </span>
              {/if}
            </a>
          {/each}
        </div>
      </section>
    </section>
  </div>
</main>

<style>
  .folio-serif {
    font-family: var(--font-serif), Georgia, 'Times New Roman', serif;
  }
</style>
