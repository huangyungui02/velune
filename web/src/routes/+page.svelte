<script lang="ts">
  import { Button } from '$lib/components/ui/button';
  import { Badge } from '$lib/components/ui/badge';
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
  import Menu from '@lucide/svelte/icons/menu';
  import Moon from '@lucide/svelte/icons/moon';
  import Mountain from '@lucide/svelte/icons/mountain';
  import Search from '@lucide/svelte/icons/search';
  import Skull from '@lucide/svelte/icons/skull';
  import Sparkles from '@lucide/svelte/icons/sparkles';
  import Sprout from '@lucide/svelte/icons/sprout';
  import UserRound from '@lucide/svelte/icons/user-round';
  import type { Component } from 'svelte';

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
      tone: 'from-stone-500 to-zinc-200'
    },
    {
      name: '加缪',
      note: '在荒诞中寻找清醒的自由。',
      initials: 'C',
      tone: 'from-amber-700 to-stone-200'
    },
    {
      name: '卡夫卡',
      note: '在荒诞的世界里，保持清醒的困惑。',
      initials: 'K',
      tone: 'from-zinc-700 to-stone-300'
    },
    {
      name: '王阳明',
      note: '知行合一，致良知。',
      initials: 'W',
      tone: 'from-neutral-700 to-amber-100'
    },
    {
      name: '惠能',
      note: '本来无一物，何处惹尘埃。',
      initials: 'H',
      tone: 'from-stone-600 to-neutral-100'
    },
    { name: '泰戈尔', note: '用诗歌拥抱世界。', initials: 'T', tone: 'from-zinc-500 to-orange-100' }
  ];
</script>

<svelte:head>
  <title>Folio | 思想漫步</title>
  <meta name="description" content="Folio 是一个关于哲学、文学和自我探索的阅读空间。" />
</svelte:head>

<main class="min-h-screen bg-[#f8f4eb] text-[#2e2a24] lg:h-screen lg:overflow-hidden">
  <div class="mx-auto flex min-h-screen w-full max-w-[1720px] lg:h-screen">
    <aside
      class="hidden w-64 shrink-0 border-r border-[#ded6c8] bg-[#f4efe5]/80 px-8 py-10 lg:flex lg:h-screen lg:flex-col lg:overflow-hidden"
    >
      <a class="folio-serif text-4xl font-semibold tracking-normal" href={resolve('/')}>Folio</a>
      <p class="mt-8 max-w-36 text-base leading-8 text-[#6c6255]">
        走进思想的世界，遇见另一种可能。
      </p>

      <nav class="mt-12 flex flex-col gap-2">
        {#each navItems as item (item.label)}
          {@const Icon = item.icon}
          <a
            class={[
              'flex h-12 items-center gap-4 rounded-2xl px-4 text-[15px] transition-colors',
              item.active
                ? 'bg-[#e9e0d1] text-[#302a22] shadow-sm'
                : 'text-[#6d6356] hover:bg-[#ece5da]'
            ]}
            href={resolve('/')}
          >
            <Icon class="size-5" strokeWidth={1.7} />
            <span>{item.label}</span>
          </a>
        {/each}
      </nav>

      <button
        class="mt-auto flex w-full items-center gap-4 rounded-2xl px-1 py-2 text-left transition-colors hover:bg-[#ece5da]"
      >
        <span
          class="flex size-14 items-center justify-center rounded-full bg-gradient-to-br from-[#d9c6aa] to-[#8b8377] text-lg font-semibold text-white"
        >
          B
        </span>
        <span class="text-sm font-medium">Bruce</span>
        <ChevronDown class="ml-auto size-4 text-[#6f665b]" strokeWidth={1.7} />
      </button>
    </aside>

    <section
      class="min-w-0 flex-1 px-4 py-4 sm:px-6 lg:h-screen lg:overflow-y-auto lg:px-8 lg:py-6"
    >
      <header
        class="mb-4 flex h-14 items-center justify-between rounded-2xl border border-[#e3dbce] bg-[#fbf7ef]/85 px-4 lg:hidden"
      >
        <a class="folio-serif text-3xl font-semibold" href={resolve('/')}>Folio</a>
        <div class="flex items-center gap-2">
          <Button variant="ghost" size="icon-sm" aria-label="搜索">
            <Search />
          </Button>
          <Button variant="ghost" size="icon-sm" aria-label="打开菜单">
            <Menu />
          </Button>
        </div>
      </header>

      <div class="relative overflow-hidden rounded-[22px] border border-[#eadfce] bg-[#f4ead9]">
        <img
          class="h-[320px] w-full object-cover object-center sm:h-[380px] lg:h-[430px]"
          src="/folio/hero.jpg"
          alt="一道通向远方山海的门"
        />
        <div
          class="absolute inset-0 bg-gradient-to-r from-[#f5ead8]/95 via-[#f5ead8]/42 to-transparent"
        ></div>
        <div class="absolute left-7 top-1/2 max-w-[420px] -translate-y-1/2 sm:left-14">
          <h1
            class="folio-serif text-6xl font-semibold leading-none tracking-normal sm:text-7xl lg:text-8xl"
          >
            Folio
          </h1>
          <p class="mt-6 text-xl leading-9 tracking-[0.08em] text-[#514a40] sm:text-2xl">
            走进思想的世界，<br />遇见另一种可能。
          </p>
          <Button
            class="mt-8 h-11 rounded-full bg-[#302b24] px-7 text-[#fff8ec] hover:bg-[#433b31]"
          >
            开始探索
            <ArrowRight data-icon="inline-end" />
          </Button>
        </div>
      </div>

      <section class="mt-7">
        <div class="mb-4 flex items-center justify-between gap-4">
          <h2 class="folio-serif text-2xl font-semibold">主题</h2>
        </div>
        <div class="flex gap-4 overflow-x-auto pb-2">
          {#each themes as theme (theme.label)}
            {@const Icon = theme.icon}
            <button
              class="flex h-11 shrink-0 items-center gap-3 rounded-full bg-[#eee6da] px-6 text-sm text-[#40392f] transition-colors hover:bg-[#e4dacb]"
            >
              <Icon class="size-5 text-[#6d6255]" strokeWidth={1.7} />
              <span>{theme.label}</span>
            </button>
          {/each}
          <button
            class="flex h-11 shrink-0 items-center gap-3 rounded-full bg-[#eee6da] px-6 text-sm text-[#40392f] transition-colors hover:bg-[#e4dacb]"
          >
            <span>更多</span>
            <ChevronDown class="size-4 text-[#6d6255]" strokeWidth={1.7} />
          </button>
        </div>
      </section>

      <section class="mt-4">
        <div class="mb-3 flex items-center justify-between">
          <h2 class="folio-serif text-2xl font-semibold">Folio</h2>
          <a
            class="flex items-center gap-2 text-sm text-[#4b4339] hover:text-[#201c17]"
            href={resolve('/')}
          >
            查看全部
            <ArrowRight class="size-4" strokeWidth={1.7} />
          </a>
        </div>

        <div class="grid gap-5 sm:grid-cols-2 xl:grid-cols-5">
          {#each folios as folio (folio.title)}
            <article
              class="overflow-hidden rounded-xl border border-[#dfd5c6] bg-[#f7f0e5] shadow-sm"
            >
              <div
                class="cover-frame relative aspect-[1.38] bg-cover"
                style:background-position={folio.position}
              >
                <Button
                  class="absolute right-3 top-3 bg-[#fbf7ef]/70 text-[#433b32] backdrop-blur hover:bg-[#fbf7ef]"
                  variant="ghost"
                  size="icon-sm"
                  aria-label={`收藏 ${folio.title}`}
                >
                  <Bookmark />
                </Button>
              </div>
              <div class="px-5 pb-5 pt-4">
                <h3 class="folio-serif text-xl font-semibold leading-7">{folio.title}</h3>
                <p class="mt-1 text-sm text-[#62584d]">{folio.author}</p>
                <div class="mt-4 flex flex-wrap gap-2">
                  {#each folio.tags as tag (tag)}
                    <Badge variant="secondary" class="bg-[#e8dfd2] text-[#5f5549]">{tag}</Badge>
                  {/each}
                </div>
              </div>
            </article>
          {/each}
        </div>
      </section>

      <section class="mt-8 pb-8">
        <div class="mb-5 flex items-center justify-between">
          <h2 class="folio-serif text-2xl font-semibold">思想家</h2>
          <a
            class="flex items-center gap-2 text-sm text-[#4b4339] hover:text-[#201c17]"
            href={resolve('/')}
          >
            查看全部
            <ArrowRight class="size-4" strokeWidth={1.7} />
          </a>
        </div>

        <div class="grid gap-x-8 gap-y-5 sm:grid-cols-2 xl:grid-cols-6">
          {#each thinkers as thinker (thinker.name)}
            <a class="group flex min-w-0 items-center gap-4" href={resolve('/')}>
              <span
                class={[
                  'folio-serif flex size-16 shrink-0 items-center justify-center rounded-full bg-gradient-to-br text-2xl font-semibold text-white shadow-sm ring-1 ring-[#d8cfbf]',
                  thinker.tone
                ]}
              >
                {thinker.initials}
              </span>
              <span class="min-w-0">
                <span class="block text-base font-medium text-[#2e2922] group-hover:text-[#17130f]"
                  >{thinker.name}</span
                >
                <span class="mt-1 line-clamp-2 block text-sm leading-6 text-[#71675b]"
                  >{thinker.note}</span
                >
              </span>
            </a>
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
