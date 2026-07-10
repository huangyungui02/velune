<script lang="ts">
  import { Button } from '$lib/components/ui/button';
  import ThemeToggle from '$lib/components/theme-toggle.svelte';
  import { resolve } from '$app/paths';
  import ArrowLeft from '@lucide/svelte/icons/arrow-left';
  import ArrowRight from '@lucide/svelte/icons/arrow-right';
  import Bookmark from '@lucide/svelte/icons/bookmark';
  import Feather from '@lucide/svelte/icons/feather';
  import Layers from '@lucide/svelte/icons/layers';
  import Waves from '@lucide/svelte/icons/waves';
  import Sun from '@lucide/svelte/icons/sun';
  import Clock from '@lucide/svelte/icons/clock';
  import BarChart2 from '@lucide/svelte/icons/bar-chart-2';
  import Tag from '@lucide/svelte/icons/tag';
  import type { Component } from 'svelte';
  import type { PageProps } from './$types';

  let { data }: PageProps = $props();
  const folio = $derived(data.folio);
  const soulers = $derived(data.soulers ?? []);

  const readingTime = $derived(
    folio.description ? Math.max(5, Math.ceil(folio.description.length / 40) + 5) : 15
  );

  const difficulty = $derived(
    folio.themes.length > 2 ? '中级' : '初级'
  );

  const themeList = $derived(
    folio.themes.length > 0 
      ? folio.themes.map((t) => t.name).join(' · ') 
      : '哲学 · 探索'
  );

  const experienceItems = $derived(
    (folio.title.includes('荒诞') || folio.author.name.includes('加缪'))
      ? [
          { label: '感受荒诞的日常', icon: Waves },
          { label: '面对沉默的世界', icon: Sun },
          { label: '选择你的态度', icon: Feather }
        ]
      : folio.themes.length
        ? folio.themes.slice(0, 3).map((theme, index) => ({
            label: `探索${theme.name}主题`,
            icon: [Waves, Sun, Feather][index] ?? Layers
          }))
        : [
            { label: '进入思想现场', icon: Waves },
            { label: '面对内心提问', icon: Sun },
            { label: '写下你的回应', icon: Feather }
          ]
  );
</script>

<svelte:head>
  <title>{folio.title} | Folio</title>
  <meta
    name="description"
    content={folio.description || folio.subtitle || `${folio.author.name} 的 Folio 体验`}
  />
</svelte:head>

<main class="min-h-screen bg-background text-foreground pb-32">
  <!-- Top Hero Banner / Illustration -->
  <div class="relative w-full h-[280px] sm:h-[360px] md:h-[420px] lg:h-[480px] overflow-hidden">
    {#if folio.coverUrl}
      <img
        src={folio.coverUrl}
        alt={folio.title}
        class="w-full h-full object-cover object-center brightness-[0.97] dark:brightness-75 transition-all duration-1000"
      />
    {:else}
      <div class="w-full h-full bg-gradient-to-b from-accent/30 via-accent/15 to-background flex items-center justify-center">
        <span class="font-serif text-3xl tracking-widest text-muted-foreground/30 italic">
          {folio.title}
        </span>
      </div>
    {/if}
    <!-- Soft overlay gradient fading into the background -->
    <div class="absolute inset-x-0 bottom-0 h-36 bg-gradient-to-t from-background to-transparent"></div>
    
    <!-- Floating Header overlaying the banner -->
    <header class="absolute top-0 inset-x-0 z-50 flex h-20 items-center justify-between px-6 sm:px-10 lg:px-16">
      <Button
        variant="ghost"
        size="icon"
        href={resolve('/')}
        class="rounded-full border border-border/20 bg-background/40 text-foreground hover:bg-background/60 shadow-sm backdrop-blur-md transition-all duration-300 hover:scale-105 active:scale-95"
        aria-label="返回"
      >
        <ArrowLeft class="size-5" />
      </Button>

      <div class="flex items-center gap-3">
        <Button
          variant="ghost"
          size="icon"
          class="rounded-full border border-border/20 bg-background/40 text-foreground hover:bg-background/60 shadow-sm backdrop-blur-md transition-all duration-300 hover:scale-105 active:scale-95"
          aria-label="收藏"
        >
          <Bookmark class="size-5" />
        </Button>
        <ThemeToggle />
      </div>
    </header>
  </div>

  <!-- Content Container (Spacious single column Book Layout) -->
  <div class="mx-auto max-w-[800px] px-6 sm:px-8 -mt-16 relative z-10">
    
    <!-- Main Title Block -->
    <div class="animate-fade-in-up">
      <h1 class="font-serif text-4xl sm:text-5xl md:text-6xl font-bold leading-[1.15] text-foreground tracking-tight">
        {folio.title}
      </h1>
    </div>

    <!-- Metadata Details Block -->
    <div class="mt-8 grid grid-cols-1 sm:grid-cols-3 gap-4 border-y border-border/30 py-6 font-serif text-sm text-muted-foreground/90 animate-fade-in-up delay-100">
      <div class="flex items-center gap-3">
        <Clock class="size-4.5 text-muted-foreground/50" strokeWidth={1.5} />
        <span>约 {readingTime} 分钟</span>
      </div>
      <div class="flex items-center gap-3">
        <BarChart2 class="size-4.5 text-muted-foreground/50" strokeWidth={1.5} />
        <span>难度: {difficulty}</span>
      </div>
      <div class="flex items-center gap-3">
        <Tag class="size-4.5 text-muted-foreground/50" strokeWidth={1.5} />
        <span>主题: {themeList}</span>
      </div>
    </div>

    <!-- Quote Card Block -->
    {#if folio.subtitle}
      <div class="my-12 rounded-2xl bg-secondary/35 border border-border/20 p-6 sm:p-8 relative overflow-hidden animate-fade-in-up delay-200">
        <svg class="absolute -top-2 -left-2 size-12 text-muted-foreground/10 font-serif" fill="currentColor" viewBox="0 0 24 24">
          <path d="M14.017 21v-7.391c0-5.704 3.731-9.57 8.983-10.609l.995 2.151c-2.432.917-3.995 3.638-3.995 5.849h4v10h-9.988zm-12 0v-7.391c0-5.704 3.748-9.57 9-10.609l.996 2.151c-2.433.917-3.996 3.638-3.996 5.849h3.983v10h-9.983z"/>
        </svg>
        <div class="relative pl-6">
          <p class="font-serif text-lg sm:text-xl leading-relaxed text-foreground/90 italic">
            {folio.subtitle}
          </p>
        </div>
      </div>
    {/if}

    <!-- Experience Intro / Description Section -->
    {#if folio.description}
      <section class="mt-12 animate-fade-in-up delay-300">
        <h2 class="font-serif text-xl font-bold text-foreground border-l-2 border-primary/50 pl-3">
          体验简介
        </h2>
        <div class="mt-6 font-serif text-base leading-relaxed text-foreground/85 space-y-4">
          <p class="text-justify font-light md:text-lg md:leading-loose">
            {folio.description}
          </p>
        </div>
      </section>
    {/if}

    <!-- You Will Experience Section -->
    <section class="mt-16 border-t border-border/20 pt-12 animate-fade-in-up delay-400">
      <h2 class="font-serif text-xl font-bold text-foreground border-l-2 border-primary/50 pl-3">
        你将体验
      </h2>
      <div class="mt-8 grid grid-cols-1 sm:grid-cols-3 gap-6">
        {#each experienceItems as item (item.label)}
          {@const Icon = item.icon as Component}
          <div class="flex flex-col items-center gap-4 rounded-2xl border border-border/30 bg-card/20 p-6 text-center hover:border-border/60 hover:bg-card/40 transition-all duration-300">
            <div class="rounded-full bg-accent/45 p-3 text-muted-foreground/75 group-hover:scale-110 transition-transform">
              <Icon class="size-6" strokeWidth={1.5} />
            </div>
            <span class="font-serif text-sm font-medium text-muted-foreground/90">{item.label}</span>
          </div>
        {/each}
      </div>
    </section>

    <!-- Related Thinkers Section -->
    {#if soulers.length > 0}
      <section class="mt-20 border-t border-border/20 pt-12 animate-fade-in-up delay-500">
        <h2 class="font-serif text-xl font-bold text-foreground border-l-2 border-primary/50 pl-3">
          关联人物
        </h2>
        <div class="mt-8 flex gap-5 overflow-x-auto pb-4 scrollbar-none snap-x snap-mandatory">
          {#each soulers as thinker (thinker.id)}
            <div class="group shrink-0 w-[160px] snap-start rounded-2xl border border-border/30 bg-card/15 p-4 hover:shadow-md hover:border-border/60 hover:-translate-y-1 transition-all duration-300">
              <div class="relative aspect-[3/4] w-full overflow-hidden rounded-xl bg-muted/30 border border-border/20">
                {#if thinker.avatarUrl}
                  <img
                    class="size-full object-cover brightness-95 contrast-[1.05] grayscale group-hover:grayscale-0 group-hover:scale-105 transition-all duration-700 ease-out"
                    src={thinker.avatarUrl}
                    alt={thinker.name}
                  />
                {:else}
                  <div class="flex size-full items-center justify-center bg-accent/20 font-serif text-2xl text-muted-foreground/40">
                    {thinker.initials}
                  </div>
                {/if}
              </div>
              <div class="mt-4 text-center">
                {#if thinker.englishName}
                  <div class="font-sans text-[11px] font-medium text-muted-foreground tracking-wider line-clamp-1">
                    {thinker.englishName}
                  </div>
                {/if}
                <div class="mt-1 font-serif text-sm font-semibold text-foreground tracking-wide line-clamp-1">
                  {thinker.name}
                </div>
              </div>
            </div>
          {/each}
        </div>
      </section>
    {/if}
  </div>

  <!-- Bottom Floating Pill Bar -->
  <div class="fixed inset-x-0 bottom-6 z-45 flex justify-center px-4 animate-fade-in">
    <!-- Main Start Button -->
    <Button
      class="group h-12 w-full max-w-xs rounded-full bg-primary text-sm font-serif tracking-widest text-primary-foreground transition-all duration-300 hover:scale-[1.02] hover:opacity-95 hover:shadow-lg active:scale-98 flex items-center justify-center shadow-[0_12px_40px_-12px_rgba(0,0,0,0.15)]"
      size="lg"
    >
      开始体验
      <ArrowRight class="ml-2 size-4 transition-transform duration-300 group-hover:translate-x-1" />
    </Button>
  </div>
</main>

<style>
  /* Hide scrollbar for Chrome, Safari and Opera */
  .scrollbar-none::-webkit-scrollbar {
    display: none;
  }
  /* Hide scrollbar for IE, Edge and Firefox */
  .scrollbar-none {
    -ms-overflow-style: none;  /* IE and Edge */
    scrollbar-width: none;  /* Firefox */
  }

  @keyframes fadeInUp {
    from {
      opacity: 0;
      transform: translateY(24px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes fadeIn {
    from {
      opacity: 0;
    }
    to {
      opacity: 1;
    }
  }

  .animate-fade-in-up {
    animation: fadeInUp 0.9s cubic-bezier(0.16, 1, 0.3, 1) both;
  }

  .animate-fade-in {
    animation: fadeIn 1.2s cubic-bezier(0.16, 1, 0.3, 1) both;
  }

  .delay-100 {
    animation-delay: 100ms;
  }
  .delay-200 {
    animation-delay: 200ms;
  }
  .delay-300 {
    animation-delay: 300ms;
  }
  .delay-400 {
    animation-delay: 400ms;
  }
  .delay-500 {
    animation-delay: 500ms;
  }
</style>
