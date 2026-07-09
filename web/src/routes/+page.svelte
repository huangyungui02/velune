<script lang="ts">
  import { Badge } from '$lib/components/ui/badge';
  import { Button } from '$lib/components/ui/button';
  import * as Avatar from '$lib/components/ui/avatar';
  import * as Card from '$lib/components/ui/card';
  import { Separator } from '$lib/components/ui/separator';
  import ThemeToggle from '$lib/components/theme-toggle.svelte';
  import { resolve } from '$app/paths';
  import ArrowRight from '@lucide/svelte/icons/arrow-right';
  import Bird from '@lucide/svelte/icons/bird';
  import Bookmark from '@lucide/svelte/icons/bookmark';
  import ChevronDown from '@lucide/svelte/icons/chevron-down';
  import Clock from '@lucide/svelte/icons/clock';
  import Heart from '@lucide/svelte/icons/heart';
  import House from '@lucide/svelte/icons/house';
  import LayoutGrid from '@lucide/svelte/icons/layout-grid';
  import Leaf from '@lucide/svelte/icons/leaf';
  import LogOut from '@lucide/svelte/icons/log-out';
  import Menu from '@lucide/svelte/icons/menu';
  import Moon from '@lucide/svelte/icons/moon';
  import Mountain from '@lucide/svelte/icons/mountain';
  import Search from '@lucide/svelte/icons/search';
  import Skull from '@lucide/svelte/icons/skull';
  import Sparkles from '@lucide/svelte/icons/sparkles';
  import Sprout from '@lucide/svelte/icons/sprout';
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

  const themes: { label: string; icon: Icon }[] = [
    { label: '存在主义', icon: Leaf },
    { label: '自由', icon: Bird },
    { label: '孤独', icon: Moon },
    { label: '爱', icon: Heart },
    { label: '意义', icon: Sparkles },
    { label: '成长', icon: Sprout },
    { label: '死亡', icon: Skull },
    { label: '反抗', icon: Mountain }
  ];

  const folios = [
    {
      title: '荒诞的清晨',
      author: 'Albert Camus',
      tags: ['荒诞', '孤独', '选择'],
      position: '0% 50%'
    },
    {
      title: '推石上山',
      author: 'Albert Camus',
      tags: ['荒诞', '反抗', '意义'],
      position: '25% 50%'
    },
    {
      title: '法之前',
      author: 'Franz Kafka',
      tags: ['孤独', '权威', '迷惘'],
      position: '50% 50%'
    },
    {
      title: '龙场夜雨',
      author: '王阳明',
      tags: ['心学', '知行合一', '内省'],
      position: '75% 50%'
    },
    {
      title: '月下独酌',
      author: '李白',
      tags: ['自由', '孤独', '诗意'],
      position: '100% 50%'
    }
  ];

  const thinkers = [
    {
      name: '尼采',
      note: '超越自我，成为你自己。',
      initials: 'N',
      tone: 'from-stone-600 to-stone-200 dark:from-stone-300 dark:to-stone-700'
    },
    {
      name: '加缪',
      note: '在荒诞中寻找清醒的自由。',
      initials: 'C',
      tone: 'from-amber-700 to-stone-200 dark:from-amber-300 dark:to-stone-800'
    },
    {
      name: '卡夫卡',
      note: '在荒诞的世界里，保持清醒的困惑。',
      initials: 'K',
      tone: 'from-zinc-700 to-stone-300 dark:from-zinc-300 dark:to-zinc-800'
    },
    {
      name: '王阳明',
      note: '知行合一，致良知。',
      initials: 'W',
      tone: 'from-neutral-700 to-amber-100 dark:from-neutral-200 dark:to-amber-950'
    },
    {
      name: '惠能',
      note: '本来无一物，何处惹尘埃。',
      initials: 'H',
      tone: 'from-stone-600 to-neutral-100 dark:from-stone-200 dark:to-neutral-800'
    },
    {
      name: '泰戈尔',
      note: '用诗歌拥抱世界。',
      initials: 'T',
      tone: 'from-zinc-500 to-orange-100 dark:from-zinc-200 dark:to-orange-950'
    }
  ];
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

      <section class="relative overflow-hidden rounded-2xl border bg-card">
        <img
          class="h-[320px] w-full object-cover object-center sm:h-[380px] lg:h-[430px]"
          src="/folio/hero.jpg"
          alt="一道通向远方山海的门"
        />
        <div
          class="absolute inset-0 bg-gradient-to-r from-background/95 via-background/52 to-transparent"
        ></div>
        <div class="absolute left-7 top-1/2 max-w-[420px] -translate-y-1/2 sm:left-14">
          <h1
            class="folio-serif text-6xl font-semibold leading-none tracking-normal sm:text-7xl lg:text-8xl"
          >
            Folio
          </h1>
          <p class="mt-6 text-xl leading-9 tracking-normal text-muted-foreground sm:text-2xl">
            走进思想的世界，<br />遇见另一种可能。
          </p>
          <Button class="mt-8 rounded-full px-7" size="lg">
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
          {#each themes as theme (theme.label)}
            {@const Icon = theme.icon}
            <Button variant="secondary" class="h-11 shrink-0 rounded-full px-5">
              <Icon data-icon="inline-start" strokeWidth={1.7} />
              <span>{theme.label}</span>
            </Button>
          {/each}
          <Button variant="outline" class="h-11 shrink-0 rounded-full px-5">
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

        <div class="grid gap-5 sm:grid-cols-2 xl:grid-cols-5">
          {#each folios as folio (folio.title)}
            <Card.Root class="rounded-xl py-0">
              <div
                class="cover-frame relative aspect-[1.38] bg-cover"
                style:background-position={folio.position}
              >
                <Button
                  class="absolute right-3 top-3 rounded-full bg-background/70 backdrop-blur hover:bg-background"
                  variant="ghost"
                  size="icon-sm"
                  aria-label={`收藏 ${folio.title}`}
                >
                  <Bookmark />
                </Button>
              </div>
              <Card.Content class="pb-5 pt-4">
                <h3 class="folio-serif text-xl font-semibold leading-7">{folio.title}</h3>
                <p class="mt-1 text-sm text-muted-foreground">{folio.author}</p>
                <div class="mt-4 flex flex-wrap gap-2">
                  {#each folio.tags as tag (tag)}
                    <Badge variant="secondary">{tag}</Badge>
                  {/each}
                </div>
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

        <div class="grid gap-x-8 gap-y-5 sm:grid-cols-2 xl:grid-cols-6">
          {#each thinkers as thinker (thinker.name)}
            <Card.Root size="sm" class="rounded-xl">
              <Card.Content>
                <a class="group flex min-w-0 items-center gap-4" href={resolve('/')}>
                  <span
                    class={[
                      'folio-serif flex size-14 shrink-0 items-center justify-center rounded-full bg-gradient-to-br text-xl font-semibold text-white shadow-sm ring-1 ring-border',
                      thinker.tone
                    ]}
                  >
                    {thinker.initials}
                  </span>
                  <span class="min-w-0">
                    <span class="block text-base font-medium group-hover:text-primary"
                      >{thinker.name}</span
                    >
                    <span class="mt-1 line-clamp-2 block text-sm leading-6 text-muted-foreground">
                      {thinker.note}
                    </span>
                  </span>
                </a>
              </Card.Content>
            </Card.Root>
          {/each}
        </div>
      </section>
    </section>
  </div>
</main>

<style>
  .folio-serif {
    font-family: Georgia, 'Times New Roman', serif;
  }

  .cover-frame {
    background-image: url('/folio/covers-sheet.jpg');
    background-size: 500% 100%;
  }
</style>
