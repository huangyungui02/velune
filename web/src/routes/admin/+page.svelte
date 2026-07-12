<script lang="ts">
  import { enhance } from '$app/forms';
  import { resolve } from '$app/paths';
  import * as Alert from '$lib/components/ui/alert';
  import * as Avatar from '$lib/components/ui/avatar';
  import { Badge } from '$lib/components/ui/badge';
  import { Button } from '$lib/components/ui/button';
  import * as Card from '$lib/components/ui/card';
  import { Checkbox } from '$lib/components/ui/checkbox';
  import * as Field from '$lib/components/ui/field';
  import { Input } from '$lib/components/ui/input';
  import { Separator } from '$lib/components/ui/separator';
  import { Spinner } from '$lib/components/ui/spinner';
  import { Textarea } from '$lib/components/ui/textarea';
  import ThemeToggle from '$lib/components/theme-toggle.svelte';
  import ArrowLeft from '@lucide/svelte/icons/arrow-left';
  import BookOpen from '@lucide/svelte/icons/book-open';
  import CircleAlert from '@lucide/svelte/icons/circle-alert';
  import CircleCheck from '@lucide/svelte/icons/circle-check';
  import ChevronRight from '@lucide/svelte/icons/chevron-right';
  import LogOut from '@lucide/svelte/icons/log-out';
  import Palette from '@lucide/svelte/icons/palette';
  import Plus from '@lucide/svelte/icons/plus';
  import Save from '@lucide/svelte/icons/save';
  import Trash2 from '@lucide/svelte/icons/trash-2';
  import UserRound from '@lucide/svelte/icons/user-round';
  import type { SubmitFunction } from '@sveltejs/kit';
  import type { Component } from 'svelte';
  import type { PageProps } from './$types';

  let { data, form }: PageProps = $props();
  let section = $state<'themes' | 'soulers' | 'folios'>('themes');

  // Selected IDs for active editors
  let selectedThemeId = $state<string | null>(null);
  let selectedSoulerId = $state<string | null>(null);
  let selectedFolioId = $state<string | null>(null);

  // Tab states
  let soulerFilter = $state<'pending' | 'approved'>('pending');
  let submitting = $state(false);

  const submit: SubmitFunction = () => {
    submitting = true;
    return async ({ update }) => {
      await update();
      submitting = false;
    };
  };

  const submitFolioBase: SubmitFunction = () => {
    submitting = true;
    return async ({ result, update }) => {
      await update({ reset: false });
      const folioId = result.type === 'success' ? result.data?.folioId : null;
      if (typeof folioId === 'string') {
        selectedFolioId = folioId;
      }
      submitting = false;
    };
  };

  const submitThemeBase: SubmitFunction = () => {
    submitting = true;
    return async ({ result, update }) => {
      await update({ reset: false });
      const themeId = result.type === 'success' ? result.data?.themeId : null;
      if (typeof themeId === 'string') selectedThemeId = themeId;
      submitting = false;
    };
  };

  function translation<T extends { lang: string }>(rows: T[] | null, lang: string) {
    return rows?.find((row) => row.lang === lang);
  }

  function activePrompt(rows: { id: string; content: string; is_active: boolean }[] | null) {
    return rows?.find((row) => row.is_active);
  }

  type Section = {
    key: typeof section;
    label: string;
    count: number;
    icon: Component;
  };

  const sections = $derived<Section[]>([
    { key: 'themes', label: 'Themes', count: data.themes.length, icon: Palette },
    { key: 'soulers', label: 'Soulers', count: data.soulers.length, icon: UserRound },
    { key: 'folios', label: 'Folios', count: data.folios.length, icon: BookOpen }
  ]);

  const pendingSoulers = $derived(data.soulers.filter((souler) => !souler.checked));
  const approvedSoulers = $derived(data.soulers.filter((souler) => souler.checked));
  const filteredSoulers = $derived(soulerFilter === 'pending' ? pendingSoulers : approvedSoulers);

  const selectedTheme = $derived(
    selectedThemeId && selectedThemeId !== 'new'
      ? data.themes.find((theme) => theme.id === selectedThemeId) || null
      : null
  );

  const selectedSouler = $derived(
    selectedSoulerId && selectedSoulerId !== 'new'
      ? data.soulers.find((souler) => souler.id === selectedSoulerId) || null
      : null
  );

  const selectedFolio = $derived(
    selectedFolioId && selectedFolioId !== 'new'
      ? data.folios.find((folio) => folio.id === selectedFolioId) || null
      : null
  );

  // Sync state after deletions or data updates
  $effect(() => {
    if (
      selectedThemeId &&
      selectedThemeId !== 'new' &&
      !data.themes.some((t) => t.id === selectedThemeId)
    ) {
      selectedThemeId = null;
    }
  });

  $effect(() => {
    if (
      selectedSoulerId &&
      selectedSoulerId !== 'new' &&
      !data.soulers.some((s) => s.id === selectedSoulerId)
    ) {
      selectedSoulerId = null;
    }
  });

  $effect(() => {
    if (
      selectedFolioId &&
      selectedFolioId !== 'new' &&
      !data.folios.some((f) => f.id === selectedFolioId)
    ) {
      selectedFolioId = null;
    }
  });

  // Reset selections when switching major section categories
  $effect(() => {
    if (section) {
      selectedThemeId = null;
      selectedSoulerId = null;
      selectedFolioId = null;
    }
  });
</script>

<svelte:head>
  <title>内容管理 | Folio Admin</title>
  <meta name="description" content="管理 Folio 的主题、思想家与内容。" />
</svelte:head>

<main
  class="min-h-screen bg-background text-foreground lg:h-screen lg:overflow-hidden flex flex-col"
>
  <!-- Top Navigation Header -->
  <header
    class="sticky top-0 z-30 border-b border-border/30 bg-background/80 backdrop-blur-md shrink-0"
  >
    <div class="mx-auto flex h-16 max-w-[1600px] items-center gap-4 px-4 sm:px-6 lg:px-8">
      <Button
        variant="ghost"
        size="icon"
        href={resolve('/')}
        class="rounded-full hover:bg-secondary size-10"
        aria-label="返回首页"
      >
        <ArrowLeft class="size-5 text-muted-foreground hover:text-foreground transition-colors" />
      </Button>
      <div class="min-w-0 flex-1">
        <h1 class="folio-serif text-xl font-medium tracking-wide">Folio Admin</h1>
        <p class="text-xs text-muted-foreground/80 mt-0.5">文学与哲学思想后台管理</p>
      </div>
      <div class="flex items-center gap-2">
        <ThemeToggle />
        <form method="POST" action="/auth/signout" class="flex">
          <Button
            type="submit"
            variant="ghost"
            size="icon"
            class="rounded-full hover:bg-secondary size-10"
            aria-label="退出登录"
          >
            <LogOut class="size-5 text-muted-foreground hover:text-foreground transition-colors" />
          </Button>
        </form>
      </div>
    </div>
  </header>

  <!-- Content Workspace -->
  <div
    class="mx-auto flex flex-col lg:flex-row min-h-0 w-full max-w-[1600px] flex-1 px-4 sm:px-6 lg:px-8 py-6 gap-6 overflow-hidden"
  >
    <!-- Sidebar Navigation -->
    <aside class="w-full lg:w-60 shrink-0 lg:flex lg:flex-col lg:h-full">
      <nav class="flex gap-2 overflow-x-auto lg:flex-col pb-2 lg:pb-0">
        {#each sections as item (item.key)}
          {@const Icon = item.icon}
          <button
            type="button"
            class={[
              'flex items-center gap-3.5 rounded-xl px-4 py-3 text-[15px] transition-all duration-300 w-full text-left',
              section === item.key
                ? 'bg-secondary text-foreground font-medium border border-border/40 shadow-xs'
                : 'text-muted-foreground hover:bg-secondary/40 hover:text-foreground border border-transparent'
            ]}
            onclick={() => (section = item.key)}
          >
            <Icon class="size-4.5 stroke-[1.6]" />
            <span class="flex-1">{item.label}</span>
            <span
              class="rounded-full bg-secondary/80 border border-border/10 px-2.5 py-0.5 text-xs text-muted-foreground font-light"
            >
              {item.count}
            </span>
          </button>
        {/each}
      </nav>
    </aside>

    <!-- Main Content Area -->
    <section class="flex-1 min-w-0 lg:h-full lg:overflow-y-auto pr-1">
      {#if form?.message}
        <Alert.Root
          class="mb-6 border-border/40 bg-card/60 shadow-xs"
          variant={form.success ? 'default' : 'destructive'}
        >
          {#if form.success}
            <CircleCheck class="size-4 text-emerald-600 dark:text-emerald-400" />
          {:else}
            <CircleAlert class="size-4 text-destructive" />
          {/if}
          <Alert.Title class="font-medium">{form.success ? '操作成功' : '操作失败'}</Alert.Title>
          <Alert.Description class="text-muted-foreground/90 mt-1 text-sm"
            >{form.message}</Alert.Description
          >
        </Alert.Root>
      {/if}

      {#if section === 'themes'}
        <div class="flex flex-col gap-6 h-full">
          {@render PageHeading('Themes', '维护思想分类的主题以及中英文名称展示。')}
          <div class="grid gap-6 lg:grid-cols-[340px_1fr] min-h-0">
            <!-- Left List Panel -->
            <div
              class="border border-border/40 bg-card/30 backdrop-blur-xs rounded-2xl overflow-hidden flex flex-col h-fit"
            >
              <div
                class="p-4 border-b border-border/20 flex items-center justify-between bg-card/50"
              >
                <span class="font-medium text-sm text-muted-foreground">主题列表</span>
                <Button
                  variant="outline"
                  class="h-8 rounded-full px-3 border border-border/30 text-xs hover:bg-secondary flex items-center gap-1 shadow-xs"
                  onclick={() => (selectedThemeId = 'new')}
                >
                  <Plus class="size-3.5" />
                  新建主题
                </Button>
              </div>
              <div class="p-2 flex flex-col gap-1 max-h-[500px] overflow-y-auto">
                {#each data.themes as theme (theme.id)}
                  {@const zh = translation(theme.themes_translations, 'zh')}
                  {@const name = zh?.name || theme.key}
                  <button
                    type="button"
                    class={[
                      'w-full text-left px-4 py-3 rounded-xl border transition-all duration-300 flex items-center justify-between group',
                      selectedThemeId === theme.id
                        ? 'bg-secondary text-foreground border-border/80 shadow-xs font-medium'
                        : 'bg-transparent text-muted-foreground border-transparent hover:bg-secondary/35 hover:text-foreground hover:border-border/20'
                    ]}
                    onclick={() => (selectedThemeId = theme.id)}
                  >
                    <div class="min-w-0">
                      <span class="block text-[14px] truncate">{name}</span>
                      <span
                        class="block text-xs text-muted-foreground/60 mt-0.5 font-light font-mono truncate"
                        >{theme.key}</span
                      >
                    </div>
                    <ChevronRight
                      class="size-4 text-muted-foreground/45 transition-transform duration-300 group-hover:translate-x-0.5"
                    />
                  </button>
                {/each}
              </div>
            </div>

            <!-- Right Editor Panel -->
            <div class="min-w-0">
              {#if selectedThemeId === null}
                <div
                  class="flex h-[400px] flex-col items-center justify-center rounded-2xl border border-dashed border-border/50 bg-card/10 p-8 text-center backdrop-blur-xs"
                >
                  <div
                    class="relative mb-4 flex size-16 items-center justify-center rounded-full bg-secondary/50 text-muted-foreground/60 border border-border/20 shadow-xs"
                  >
                    <Palette class="size-7 stroke-[1.5]" />
                  </div>
                  <h3 class="folio-serif text-lg font-medium text-foreground">选择或创建主题</h3>
                  <p
                    class="mt-2 max-w-sm text-sm text-muted-foreground/80 leading-relaxed font-light"
                  >
                    “存在、自由、孤独、爱与死亡”<br
                    />在文字与思绪的交织中，选择一个主题进行编辑，或创建新的分类。
                  </p>
                  <Button
                    variant="outline"
                    class="mt-6 rounded-full px-5 border border-border/30 hover:-translate-y-0.5 transition-all duration-300 shadow-xs"
                    onclick={() => (selectedThemeId = 'new')}
                  >
                    <Plus class="size-4 mr-1.5" />
                    新建主题
                  </Button>
                </div>
              {:else if selectedThemeId === 'new'}
                {@render ThemeForm(undefined, submitting, submitThemeBase, submit)}
              {:else if selectedTheme}
                {@render ThemeForm(selectedTheme, submitting, submitThemeBase, submit)}
              {/if}
            </div>
          </div>
        </div>
      {:else if section === 'soulers'}
        <div class="flex flex-col gap-6 h-full">
          {@render PageHeading('Soulers', '管理与审核思想家的生平介绍、Wiki 映射及别名设置。')}
          <div class="grid gap-6 lg:grid-cols-[340px_1fr] min-h-0">
            <!-- Left List Panel -->
            <div
              class="border border-border/40 bg-card/30 backdrop-blur-xs rounded-2xl overflow-hidden flex flex-col h-fit"
            >
              <div
                class="p-4 border-b border-border/20 flex items-center justify-between bg-card/50"
              >
                <span class="font-medium text-sm text-muted-foreground">人物列表</span>
                <Button
                  variant="outline"
                  class="h-8 rounded-full px-3 border border-border/30 text-xs hover:bg-secondary flex items-center gap-1 shadow-xs"
                  onclick={() => (selectedSoulerId = 'new')}
                >
                  <Plus class="size-3.5" />
                  新建人物
                </Button>
              </div>
              <div class="p-2 border-b border-border/10 bg-card/25 flex gap-1">
                <button
                  type="button"
                  class={[
                    'flex-1 text-center py-1.5 text-xs rounded-lg transition-all duration-200 font-medium',
                    soulerFilter === 'pending'
                      ? 'bg-secondary text-foreground shadow-xs border border-border/30'
                      : 'text-muted-foreground hover:text-foreground'
                  ]}
                  onclick={() => (soulerFilter = 'pending')}
                >
                  待审核
                  <span
                    class="ml-1.5 px-2 py-0.2 rounded-full bg-destructive/10 text-destructive text-[10px] font-semibold"
                  >
                    {pendingSoulers.length}
                  </span>
                </button>
                <button
                  type="button"
                  class={[
                    'flex-1 text-center py-1.5 text-xs rounded-lg transition-all duration-200 font-medium',
                    soulerFilter === 'approved'
                      ? 'bg-secondary text-foreground shadow-xs border border-border/30'
                      : 'text-muted-foreground hover:text-foreground'
                  ]}
                  onclick={() => (soulerFilter = 'approved')}
                >
                  已审核
                  <span
                    class="ml-1.5 px-2 py-0.2 rounded-full bg-muted-foreground/10 text-muted-foreground text-[10px]"
                  >
                    {approvedSoulers.length}
                  </span>
                </button>
              </div>
              <div class="p-2 flex flex-col gap-1 max-h-[500px] overflow-y-auto">
                {#each filteredSoulers as souler (souler.id)}
                  {@const zh = translation(souler.souler_profile, 'zh')}
                  {@const en = translation(souler.souler_profile, 'en')}
                  {@const name = zh?.name || en?.name || souler.wiki_id || '未命名人物'}
                  <button
                    type="button"
                    class={[
                      'w-full text-left px-3 py-2.5 rounded-xl border transition-all duration-300 flex items-center gap-3 group',
                      selectedSoulerId === souler.id
                        ? 'bg-secondary text-foreground border-border/80 shadow-xs font-medium'
                        : 'bg-transparent text-muted-foreground border-transparent hover:bg-secondary/35 hover:text-foreground hover:border-border/20'
                    ]}
                    onclick={() => (selectedSoulerId = souler.id)}
                  >
                    <Avatar.Root
                      class="h-11 aspect-[3/4] rounded-lg border border-border/40 shadow-xs after:rounded-lg"
                    >
                      {#if souler.avatar_url}
                        <Avatar.Image
                          src={souler.avatar_url}
                          alt={name}
                          class="rounded-lg object-cover"
                        />
                      {/if}
                      <Avatar.Fallback
                        class="rounded-lg bg-secondary text-muted-foreground font-semibold text-xs"
                      >
                        {name.slice(0, 1).toUpperCase()}
                      </Avatar.Fallback>
                    </Avatar.Root>
                    <div class="min-w-0 flex-1">
                      <span class="block text-[14px] truncate">{name}</span>
                      <span
                        class="block text-xs text-muted-foreground/60 truncate font-light mt-0.5"
                      >
                        {souler.wiki_id || 'No Wiki ID'}
                      </span>
                    </div>
                    <ChevronRight
                      class="size-4 text-muted-foreground/45 transition-transform duration-300 group-hover:translate-x-0.5"
                    />
                  </button>
                {:else}
                  <div class="py-8 text-center text-xs text-muted-foreground/60 font-light">
                    暂无人物
                  </div>
                {/each}
              </div>
            </div>

            <!-- Right Editor Panel -->
            <div class="min-w-0">
              {#if selectedSoulerId === null}
                <div
                  class="flex h-[400px] flex-col items-center justify-center rounded-2xl border border-dashed border-border/50 bg-card/10 p-8 text-center backdrop-blur-xs"
                >
                  <div
                    class="relative mb-4 flex size-16 items-center justify-center rounded-full bg-secondary/50 text-muted-foreground/60 border border-border/20 shadow-xs"
                  >
                    <UserRound class="size-7 stroke-[1.5]" />
                  </div>
                  <h3 class="folio-serif text-lg font-medium text-foreground">选择或新建人物</h3>
                  <p
                    class="mt-2 max-w-sm text-sm text-muted-foreground/80 leading-relaxed font-light"
                  >
                    “每一个伟大的思想家都在这里留下了痕迹。”<br
                    />选择左侧人物以完善其资料，或开启新的生成任务。
                  </p>
                  <Button
                    variant="outline"
                    class="mt-6 rounded-full px-5 border border-border/30 hover:-translate-y-0.5 transition-all duration-300 shadow-xs"
                    onclick={() => (selectedSoulerId = 'new')}
                  >
                    <Plus class="size-4 mr-1.5" />
                    新建人物
                  </Button>
                </div>
              {:else if selectedSoulerId === 'new'}
                {@render CreateSouler(submitting, submit)}
              {:else if selectedSouler}
                {@render SoulerDetails(selectedSouler, submitting, submit)}
              {/if}
            </div>
          </div>
        </div>
      {:else}
        <div class="flex flex-col gap-6 h-full">
          {@render PageHeading(
            'Folios',
            '管理每一本思想集的属性、中英文核心句与生成 System Prompt。'
          )}
          <div class="grid gap-6 lg:grid-cols-[340px_1fr] min-h-0">
            <!-- Left List Panel -->
            <div
              class="border border-border/40 bg-card/30 backdrop-blur-xs rounded-2xl overflow-hidden flex flex-col h-fit"
            >
              <div
                class="p-4 border-b border-border/20 flex items-center justify-between bg-card/50"
              >
                <span class="font-medium text-sm text-muted-foreground">Folio 列表</span>
                <Button
                  variant="outline"
                  class="h-8 rounded-full px-3 border border-border/30 text-xs hover:bg-secondary flex items-center gap-1 shadow-xs"
                  onclick={() => (selectedFolioId = 'new')}
                >
                  <Plus class="size-3.5" />
                  新建 Folio
                </Button>
              </div>
              <div class="p-2 flex flex-col gap-1 max-h-[550px] overflow-y-auto">
                {#each data.folios as folio (folio.id)}
                  {@const zh = translation(folio.folio_translations, 'zh')}
                  {@const en = translation(folio.folio_translations, 'en')}
                  {@const title = zh?.title || en?.title || '未命名 Folio'}
                  {@const souler = data.soulers.find((s) => s.id === folio.souler_id)}
                  {@const soulerZh = translation(souler?.souler_profile ?? null, 'zh')}
                  {@const soulerName = soulerZh?.name || souler?.wiki_id || '未知作者'}
                  <button
                    type="button"
                    class={[
                      'w-full text-left px-4 py-3.5 rounded-xl border transition-all duration-300 flex flex-col gap-1.5 group',
                      selectedFolioId === folio.id
                        ? 'bg-secondary text-foreground border-border/80 shadow-xs font-medium'
                        : 'bg-transparent text-muted-foreground border-transparent hover:bg-secondary/35 hover:text-foreground hover:border-border/20'
                    ]}
                    onclick={() => (selectedFolioId = folio.id)}
                  >
                    <div class="flex items-start justify-between gap-2 w-full">
                      <span
                        class="text-[14px] leading-tight font-medium text-foreground group-hover:text-primary transition-colors line-clamp-1"
                      >
                        {title}
                      </span>
                      <ChevronRight
                        class="size-4 text-muted-foreground/45 transition-transform duration-300 group-hover:translate-x-0.5 shrink-0 mt-0.5"
                      />
                    </div>
                    <div
                      class="flex items-center justify-between gap-2 w-full text-xs text-muted-foreground/75 font-light"
                    >
                      <span>{soulerName}</span>
                      <div class="flex gap-1.5">
                        {#if folio.featured}
                          <span
                            class="px-1.5 py-0.2 rounded-md bg-amber-500/10 text-amber-600 dark:text-amber-400 text-[10px] border border-amber-500/15"
                          >
                            精选
                          </span>
                        {/if}
                        {#if folio.is_public}
                          <span
                            class="px-1.5 py-0.2 rounded-md bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 text-[10px] border border-emerald-500/15"
                          >
                            已发布
                          </span>
                        {:else}
                          <span
                            class="px-1.5 py-0.2 rounded-md bg-zinc-500/10 text-zinc-500 text-[10px] border border-zinc-500/15"
                          >
                            草稿
                          </span>
                        {/if}
                      </div>
                    </div>
                  </button>
                {/each}
              </div>
            </div>

            <!-- Right Editor Panel -->
            <div class="min-w-0">
              {#if selectedFolioId === null}
                <div
                  class="flex h-[400px] flex-col items-center justify-center rounded-2xl border border-dashed border-border/50 bg-card/10 p-8 text-center backdrop-blur-xs"
                >
                  <div
                    class="relative mb-4 flex size-16 items-center justify-center rounded-full bg-secondary/50 text-muted-foreground/60 border border-border/20 shadow-xs"
                  >
                    <BookOpen class="size-7 stroke-[1.5]" />
                  </div>
                  <h3 class="folio-serif text-lg font-medium text-foreground">选择或新建 Folio</h3>
                  <p
                    class="mt-2 max-w-sm text-sm text-muted-foreground/80 leading-relaxed font-light"
                  >
                    “荒诞、存在、反抗与诗意。”<br
                    />选择左侧思想集以查看并编辑内容，或开启一份新的双语创作。
                  </p>
                  <Button
                    variant="outline"
                    class="mt-6 rounded-full px-5 border border-border/30 hover:-translate-y-0.5 transition-all duration-300 shadow-xs"
                    onclick={() => (selectedFolioId = 'new')}
                  >
                    <Plus class="size-4 mr-1.5" />
                    新建 Folio
                  </Button>
                </div>
              {:else if selectedFolioId === 'new'}
                {@render FolioForm(data, undefined, submitting, submitFolioBase, submit)}
              {:else if selectedFolio}
                {@render FolioForm(data, selectedFolio, submitting, submitFolioBase, submit)}
              {/if}
            </div>
          </div>
        </div>
      {/if}
    </section>
  </div>
</main>

{#snippet PageHeading(title: string, description: string)}
  <div class="border-b border-border/10 pb-4 mb-4">
    <h2 class="folio-serif text-3xl font-medium tracking-tight text-foreground">{title}</h2>
    <p class="mt-1.5 text-sm text-muted-foreground/80 leading-relaxed font-light">{description}</p>
  </div>
{/snippet}

{#snippet Actions(id: string | undefined, deleteAction: string, submitting: boolean)}
  <div class="flex items-center justify-between gap-3 w-full">
    {#if id}
      <Button
        type="submit"
        variant="destructive"
        class="rounded-full px-5 hover:bg-destructive/95 transition-all shadow-sm"
        formaction={deleteAction}
        onclick={(event) => {
          if (!confirm('此操作不可撤销，确定删除？')) event.preventDefault();
        }}
      >
        <Trash2 data-icon="inline-start" class="size-4 mr-1.5" />
        删除
      </Button>
    {:else}
      <span></span>
    {/if}
    <Button
      type="submit"
      class="rounded-full px-6 bg-primary text-primary-foreground hover:bg-primary/90 transition-all shadow-sm"
      disabled={submitting}
    >
      {#if submitting}
        <Spinner data-icon="inline-start" class="size-4 mr-1.5" />
      {:else if id}
        <Save data-icon="inline-start" class="size-4 mr-1.5" />
      {:else}
        <Plus data-icon="inline-start" class="size-4 mr-1.5" />
      {/if}
      {id ? '保存修改' : '新建'}
    </Button>
  </div>
{/snippet}

{#snippet ThemeForm(
  theme: PageProps['data']['themes'][number] | undefined = undefined,
  submitting: boolean,
  submitBase: SubmitFunction,
  submit: SubmitFunction
)}
  {@const zh = translation(theme?.themes_translations ?? null, 'zh')}
  {@const en = translation(theme?.themes_translations ?? null, 'en')}
  <Card.Root
    class="border border-border/40 bg-card/60 backdrop-blur-xs shadow-xs rounded-2xl p-2 lg:p-4"
  >
    <Card.Header class="pb-4">
      <Card.Title class="folio-serif text-2xl font-semibold">
        {theme ? zh?.name || theme.key : '新建 Theme'}
      </Card.Title>
      <Card.Description class="text-muted-foreground/80 mt-1">
        {theme?.key
          ? `修改主题 ${theme.key} 的多语言展示属性`
          : '创建一个可供思想家或思想集关联的公共主题'}
      </Card.Description>
    </Card.Header>
    <Card.Content class="space-y-6">
      <form method="POST" action="?/saveThemeBase" use:enhance={submitBase} class="space-y-5">
        <input type="hidden" name="id" value={theme?.id ?? ''} />
        <Field.FieldGroup>
          <Field.Field>
            <Field.FieldLabel for="theme-key-{theme?.id ?? 'new'}" class="text-sm font-medium"
              >标识 Key</Field.FieldLabel
            >
            <Input
              id="theme-key-{theme?.id ?? 'new'}"
              name="key"
              value={theme?.key ?? ''}
              class="bg-background/50 border-border/40 focus-visible:ring-primary/20 rounded-xl"
              required
            />
            <Field.FieldDescription class="text-xs text-muted-foreground/70 mt-1">
              稳定的小写英文标识符，例如 existentialism、solitude。
            </Field.FieldDescription>
          </Field.Field>
        </Field.FieldGroup>
        <div class="flex justify-end">
          <Button type="submit" class="rounded-full px-5" disabled={submitting}>
            <Save data-icon="inline-start" class="size-4 mr-1.5" />
            {theme ? '保存主题标识' : '创建主题'}
          </Button>
        </div>
      </form>
      {#if theme}
        <Separator class="bg-border/40" />
        <div class="grid gap-5 sm:grid-cols-2">
          {#each ['zh', 'en'] as lang (lang)}
            {@const value = lang === 'zh' ? zh : en}
            <form
              method="POST"
              action="?/saveThemeTranslation"
              use:enhance={submit}
              class="space-y-3"
            >
              <input type="hidden" name="id" value={theme.id} />
              <input type="hidden" name="lang" value={lang} />
              <Field.Field>
                <Field.FieldLabel for="theme-{lang}-{theme.id}" class="text-sm font-medium">
                  {lang === 'zh' ? '中文名称' : '英文名称 (English)'}
                </Field.FieldLabel>
                <Input
                  id="theme-{lang}-{theme.id}"
                  name="name"
                  value={value?.name ?? ''}
                  class="bg-background/50 border-border/40 focus-visible:ring-primary/20 rounded-xl"
                  required
                />
              </Field.Field>
              <div class="flex justify-end">
                <Button
                  type="submit"
                  variant="outline"
                  size="sm"
                  class="rounded-full px-4"
                  disabled={submitting}
                >
                  <Save data-icon="inline-start" class="size-3.5 mr-1" />
                  保存{lang === 'zh' ? '中文' : '英文'}
                </Button>
              </div>
            </form>
          {/each}
        </div>
      {:else}
        <p class="text-sm text-muted-foreground/70">创建后可分别填写中文和英文名称。</p>
      {/if}
    </Card.Content>
    {#if theme}
      <Card.Footer class="mt-6 border-t border-border/10 pt-5">
        <form method="POST" action="?/deleteTheme" use:enhance={submit}>
          <input type="hidden" name="id" value={theme.id} />
          <Button
            type="submit"
            variant="destructive"
            class="rounded-full px-5"
            disabled={submitting}
          >
            <Trash2 data-icon="inline-start" class="size-4 mr-1.5" />
            删除主题
          </Button>
        </form>
      </Card.Footer>
    {/if}
  </Card.Root>
{/snippet}

{#snippet CreateSouler(submitting: boolean, submit: SubmitFunction)}
  <Card.Root
    class="border border-border/40 bg-card/60 backdrop-blur-xs shadow-xs rounded-2xl p-2 lg:p-4"
  >
    <Card.Header class="pb-4">
      <Card.Title class="folio-serif text-2xl font-semibold">新建人物 (AI 自动生成)</Card.Title>
      <Card.Description class="text-muted-foreground/80 mt-1">
        输入人物姓名并选择背景抓取的主语言。提交后，AI Agent
        将在后台自动收集维基百科并填充人物资料。
      </Card.Description>
    </Card.Header>
    <form method="POST" action="?/createSouler" use:enhance={submit}>
      <Card.Content>
        <Field.FieldGroup class="space-y-5">
          <div class="grid gap-5 sm:grid-cols-[1fr_200px]">
            <Field.Field>
              <Field.FieldLabel for="new-souler-name" class="text-sm font-medium"
                >人物姓名</Field.FieldLabel
              >
              <Input
                id="new-souler-name"
                name="name"
                placeholder="例如：Albert Camus 或 加缪"
                class="bg-background/50 border-border/40 focus-visible:ring-primary/20 rounded-xl"
                required
              />
              <Field.FieldDescription class="text-xs text-muted-foreground/70 mt-1">
                请输入该人物的官方译名或英文原名。
              </Field.FieldDescription>
            </Field.Field>
            <Field.Field>
              <Field.FieldLabel for="new-souler-lang" class="text-sm font-medium"
                >首选检索语言</Field.FieldLabel
              >
              <select
                id="new-souler-lang"
                name="lang"
                class="h-10 w-full rounded-xl border border-border/40 bg-background/50 focus-visible:ring-primary/20 px-3 text-sm transition-all focus:outline-hidden focus:ring-2 focus:ring-ring"
                required
              >
                <option value="zh">中文 (Chinese)</option>
                <option value="en">English</option>
              </select>
              <Field.FieldDescription class="text-xs text-muted-foreground/70 mt-1">
                AI 将优先以此语言检索人物百科。
              </Field.FieldDescription>
            </Field.Field>
          </div>
        </Field.FieldGroup>
      </Card.Content>
      <Card.Footer class="mt-6 border-t border-t-border/10 pt-5 justify-end">
        <Button
          type="submit"
          class="rounded-full px-6 bg-primary text-primary-foreground hover:bg-primary/90 transition-all shadow-sm"
          disabled={submitting}
        >
          {#if submitting}
            <Spinner data-icon="inline-start" class="size-4 mr-1.5" />
          {:else}
            <Plus data-icon="inline-start" class="size-4 mr-1.5" />
          {/if}
          提交并开始生成
        </Button>
      </Card.Footer>
    </form>
  </Card.Root>
{/snippet}

{#snippet SoulerDetails(
  souler: PageProps['data']['soulers'][number],
  submitting: boolean,
  submit: SubmitFunction
)}
  {@const zh = translation(souler.souler_profile, 'zh')}
  {@const en = translation(souler.souler_profile, 'en')}
  {@const displayName = zh?.name || en?.name || souler.wiki_id || '未命名人物'}
  <Card.Root
    class="border border-border/40 bg-card/60 backdrop-blur-xs shadow-xs rounded-2xl overflow-hidden p-2 lg:p-4"
  >
    <Card.Header class="pb-5 border-b border-border/10">
      <div class="flex items-center justify-between gap-4">
        <div class="flex items-center gap-3">
          <Avatar.Root
            class="h-16 aspect-[3/4] rounded-xl border border-border/40 shadow-xs after:rounded-xl"
          >
            {#if souler.avatar_url}
              <Avatar.Image
                src={souler.avatar_url}
                alt={displayName}
                class="rounded-xl object-cover"
              />
            {/if}
            <Avatar.Fallback
              class="rounded-xl bg-secondary text-muted-foreground font-semibold text-sm"
            >
              {displayName.slice(0, 1).toUpperCase()}
            </Avatar.Fallback>
          </Avatar.Root>
          <div>
            <Card.Title class="folio-serif text-2xl font-semibold leading-tight"
              >{displayName}</Card.Title
            >
            <Card.Description class="text-xs text-muted-foreground/75 font-mono mt-0.5"
              >{souler.wiki_id || souler.id}</Card.Description
            >
          </div>
        </div>
        <span
          class={[
            'px-2.5 py-0.5 rounded-full text-xs font-medium border',
            souler.checked
              ? 'bg-emerald-500/10 text-emerald-600 border-emerald-500/20'
              : 'bg-amber-500/10 text-amber-600 border-amber-500/20'
          ]}
        >
          {souler.checked ? '已审核' : '待审核'}
        </span>
      </div>
    </Card.Header>
    <div class="p-6 space-y-6">
      <form
        method="POST"
        action="?/saveSoulerBase"
        enctype="multipart/form-data"
        use:enhance={submit}
        class="space-y-5"
      >
        <input type="hidden" name="id" value={souler.id} />
        <h3
          class="text-[15px] font-medium text-foreground border-l-2 border-primary pl-2 leading-none"
        >
          基础资料
        </h3>
        <Field.FieldGroup class="space-y-4">
          <div class="grid gap-5 sm:grid-cols-2">
            <Field.Field>
              <Field.FieldLabel for="souler-wiki-{souler.id}" class="text-sm font-medium"
                >Wiki ID</Field.FieldLabel
              >
              <Input
                id="souler-wiki-{souler.id}"
                name="wiki_id"
                value={souler.wiki_id ?? ''}
                placeholder="百科标识，例如 Albert_Camus"
                class="bg-background/50 border-border/40 focus-visible:ring-primary/20 rounded-xl"
              />
            </Field.Field>
            <Field.Field>
              <Field.FieldLabel for="souler-avatar-{souler.id}" class="text-sm font-medium"
                >上传头像</Field.FieldLabel
              >
              <Input
                id="souler-avatar-{souler.id}"
                name="avatar_file"
                type="file"
                accept="image/png"
                class="bg-background/50 border-border/40 focus-visible:ring-primary/20 rounded-xl"
              />
              <Field.FieldDescription class="text-xs text-muted-foreground/70 mt-1">
                PNG，最大 5 MB。保存为 <code>soulers/{souler.wiki_id || '{wiki_id}'}.png</code>
              </Field.FieldDescription>
            </Field.Field>
          </div>
          <Field.Field orientation="horizontal" class="py-2">
            <Checkbox
              id="souler-checked-{souler.id}"
              name="checked"
              checked={souler.checked}
              class="border-border/60 data-[state=checked]:bg-primary rounded-md"
            />
            <Field.FieldLabel
              for="souler-checked-{souler.id}"
              class="text-sm font-medium select-none cursor-pointer"
            >
              确认审核通过（已审核人物才会公开展示）
            </Field.FieldLabel>
          </Field.Field>
        </Field.FieldGroup>
        <div class="flex justify-end pt-2">
          <Button
            type="submit"
            class="rounded-full px-5 bg-primary text-primary-foreground hover:bg-primary/90 transition-all shadow-sm"
            disabled={submitting}
          >
            {#if submitting}
              <Spinner data-icon="inline-start" class="size-4 mr-1.5" />
            {:else}
              <Save data-icon="inline-start" class="size-4 mr-1.5" />
            {/if}
            保存基础资料
          </Button>
        </div>
      </form>
      <Separator class="bg-border/40" />
      <form method="POST" action="?/saveSoulerAliases" use:enhance={submit} class="space-y-4">
        <input type="hidden" name="id" value={souler.id} />
        <h3
          class="text-[15px] font-medium text-foreground border-l-2 border-primary pl-2 leading-none"
        >
          别名
        </h3>
        <Field.Field>
          <Field.FieldLabel for="souler-aliases-{souler.id}" class="text-sm font-medium"
            >别名列表</Field.FieldLabel
          >
          <Textarea
            id="souler-aliases-{souler.id}"
            name="aliases"
            value={souler.souler_aliases?.map((item) => item.alias).join('\n') ?? ''}
            placeholder="每行输入一个别名，用于模糊匹配"
            rows={3}
            class="bg-background/50 border-border/40 focus-visible:ring-primary/20 rounded-xl resize-y"
          />
        </Field.Field>
        <div class="flex justify-end">
          <Button type="submit" variant="outline" class="rounded-full px-5" disabled={submitting}>
            <Save data-icon="inline-start" class="size-4 mr-1.5" />保存别名
          </Button>
        </div>
      </form>
      <Separator class="bg-border/40" />
      <form method="POST" action="?/saveSoulerKeywords" use:enhance={submit} class="space-y-4">
        <input type="hidden" name="id" value={souler.id} />
        <h3
          class="text-[15px] font-medium text-foreground border-l-2 border-primary pl-2 leading-none"
        >
          关键词
        </h3>
        <Field.Field>
          <Field.FieldLabel for="souler-keywords-{souler.id}" class="text-sm font-medium"
            >关键词、语言与权重</Field.FieldLabel
          >
          <Textarea
            id="souler-keywords-{souler.id}"
            name="keywords"
            value={souler.souler_keyword
              ?.map(
                (item) =>
                  `${item.keywords?.word ?? ''} | ${item.keywords?.language ?? 'zh'} | ${item.weight ?? 1}`
              )
              .join('\n') ?? ''}
            placeholder="虚无 | zh | 0.95&#10;nihilism | en | 0.95"
            rows={5}
            class="bg-background/50 border-border/40 focus-visible:ring-primary/20 rounded-xl resize-y font-mono text-sm"
          />
          <Field.FieldDescription class="text-xs text-muted-foreground/70 mt-1">
            每行格式：关键词 | zh 或 en | 0 到 1 的权重。保存会只重建该人物的关键词关联。
          </Field.FieldDescription>
        </Field.Field>
        <div class="flex justify-end">
          <Button type="submit" variant="outline" class="rounded-full px-5" disabled={submitting}>
            <Save data-icon="inline-start" class="size-4 mr-1.5" />保存关键词
          </Button>
        </div>
      </form>
      <Separator class="bg-border/40" />
      <div>
        <h3
          class="text-[15px] font-medium text-foreground border-l-2 border-primary pl-2 leading-none mb-4"
        >
          详细生平介绍
        </h3>
        <div class="grid gap-6 lg:grid-cols-2">
          <div class="border border-border/30 bg-background/30 rounded-xl p-4">
            {@render SoulerProfile(souler.id, 'zh', '中文资料 (Chinese)', zh, submitting, submit)}
          </div>
          <div class="border border-border/30 bg-background/30 rounded-xl p-4">
            {@render SoulerProfile(souler.id, 'en', '英文资料 (English)', en, submitting, submit)}
          </div>
        </div>
      </div>
    </div>
    <div class="bg-muted/10 border-t border-border/10 p-5 flex items-center justify-between">
      <form method="POST" action="?/deleteSouler" use:enhance={submit}>
        <input type="hidden" name="id" value={souler.id} />
        <Button
          type="submit"
          variant="destructive"
          class="rounded-full px-5 hover:bg-destructive/95 transition-all shadow-sm"
          disabled={submitting}
          onclick={(event) => {
            if (!confirm('此操作将永久删除人物及其双语包。确认删除？')) event.preventDefault();
          }}
        >
          <Trash2 data-icon="inline-start" class="size-4 mr-1.5" />
          删除人物
        </Button>
      </form>
    </div>
  </Card.Root>
{/snippet}

{#snippet SoulerProfile(
  soulerId: string,
  lang: 'zh' | 'en',
  title: string,
  profile: { name: string; introduction: string | null } | undefined,
  submitting: boolean,
  submit: SubmitFunction
)}
  <form method="POST" action="?/saveSoulerProfile" use:enhance={submit} class="space-y-4">
    <input type="hidden" name="id" value={soulerId} />
    <input type="hidden" name="lang" value={lang} />
    <Field.FieldGroup class="space-y-4">
      <div class="flex items-center justify-between">
        <span class="text-sm font-semibold text-foreground">{title}</span>
      </div>
      <Field.Field>
        <Field.FieldLabel
          for="souler-name-{lang}-{soulerId}"
          class="text-xs font-medium text-muted-foreground">翻译姓名</Field.FieldLabel
        >
        <Input
          id="souler-name-{lang}-{soulerId}"
          name="name"
          value={profile?.name ?? ''}
          placeholder={lang === 'zh' ? '中文译名，如：阿尔贝·加缪' : 'e.g. Albert Camus'}
          class="bg-background/50 border-border/40 focus-visible:ring-primary/20 rounded-xl h-9 text-sm"
          required
        />
      </Field.Field>
      <Field.Field>
        <Field.FieldLabel
          for="souler-introduction-{lang}-{soulerId}"
          class="text-xs font-medium text-muted-foreground">生平介绍</Field.FieldLabel
        >
        <Textarea
          id="souler-introduction-{lang}-{soulerId}"
          name="introduction"
          value={profile?.introduction ?? ''}
          placeholder={lang === 'zh'
            ? '输入该语言对应的人物理念及生平介绍...'
            : 'Enter bio details...'}
          rows={10}
          class="bg-background/50 border-border/40 focus-visible:ring-primary/20 rounded-xl resize-y text-sm leading-relaxed"
        />
      </Field.Field>
      <div class="flex justify-end">
        <Button
          type="submit"
          variant="outline"
          size="sm"
          class="rounded-full px-4 border-border/30 hover:bg-secondary"
          disabled={submitting}
        >
          {#if submitting}
            <Spinner data-icon="inline-start" class="size-3.5 mr-1" />
          {:else}
            <Save data-icon="inline-start" class="size-3.5 mr-1" />
          {/if}
          保存{lang === 'zh' ? '中文' : '英文'}
        </Button>
      </div>
    </Field.FieldGroup>
  </form>
{/snippet}

{#snippet FolioForm(
  data: PageProps['data'],
  folio: PageProps['data']['folios'][number] | undefined = undefined,
  submitting: boolean,
  submitBase: SubmitFunction,
  submit: SubmitFunction
)}
  {@const zh = translation(folio?.folio_translations ?? null, 'zh')}
  {@const en = translation(folio?.folio_translations ?? null, 'en')}
  {@const prompt = activePrompt(folio?.folio_prompts ?? null)}
  {@const selectedThemes = new Set(folio?.folio_themes?.map((item) => item.theme_id) ?? [])}
  <Card.Root
    class="border border-border/40 bg-card/60 backdrop-blur-xs shadow-xs rounded-2xl overflow-hidden p-2 lg:p-4"
  >
    <Card.Header class="pb-5 border-b border-border/10">
      <div class="flex items-center justify-between gap-4">
        <div>
          <Card.Title class="folio-serif text-2xl font-semibold">
            {folio ? zh?.title || en?.title || '未命名 Folio' : '新建 Folio'}
          </Card.Title>
          <Card.Description class="text-xs text-muted-foreground/80 mt-1">
            {folio ? '编辑此思想集的内容与属性' : '创建一份新的双语思想集并发布'}
          </Card.Description>
        </div>
        <div class="flex gap-2">
          {#if folio}
            <span
              class={[
                'px-2.5 py-0.5 rounded-full text-xs font-medium border',
                folio.is_public
                  ? 'bg-emerald-500/10 text-emerald-600 border-emerald-500/20'
                  : 'bg-zinc-500/10 text-zinc-500 border-zinc-500/20'
              ]}
            >
              {folio.is_public ? '已发布' : '草稿'}
            </span>
            {#if folio.featured}
              <span
                class="px-2.5 py-0.5 rounded-full text-xs font-medium border bg-amber-500/10 text-amber-600 border-amber-500/20"
              >
                精选
              </span>
            {/if}
          {/if}
        </div>
      </div>
    </Card.Header>
    <Card.Content class="space-y-6 p-6">
      <form
        method="POST"
        action="?/saveFolioBase"
        enctype="multipart/form-data"
        use:enhance={submitBase}
        class="space-y-6"
      >
        <input type="hidden" name="id" value={folio?.id ?? ''} />
        <h3
          class="text-[15px] font-medium text-foreground border-l-2 border-primary pl-2 leading-none"
        >
          核心关联
        </h3>
        <div class="grid gap-5 sm:grid-cols-2">
          <Field.Field>
            <Field.FieldLabel for="folio-souler-{folio?.id ?? 'new'}" class="text-sm font-medium"
              >思想家 (Souler)</Field.FieldLabel
            >
            <select
              id="folio-souler-{folio?.id ?? 'new'}"
              name="souler_id"
              class="h-10 w-full rounded-xl border border-border/40 bg-background/50 focus-visible:ring-primary/20 px-3 text-sm transition-all focus:outline-hidden focus:ring-2 focus:ring-ring"
              required
            >
              <option value="">-- 选择思想家 --</option>
              {#each data.soulers as souler (souler.id)}
                {@const profile = translation(souler.souler_profile, 'zh')}
                <option value={souler.id} selected={souler.id === folio?.souler_id}>
                  {profile?.name || souler.wiki_id || souler.id}
                </option>
              {/each}
            </select>
            <Field.FieldDescription class="text-xs text-muted-foreground/70 mt-1">
              该本思想集所归属的思想家。
            </Field.FieldDescription>
          </Field.Field>
          <Field.Field>
            <Field.FieldLabel for="folio-cover-{folio?.id ?? 'new'}" class="text-sm font-medium"
              >上传封面</Field.FieldLabel
            >
            {#if folio?.cover_image_url}
              <img
                src={folio.cover_image_url}
                alt={zh?.title || en?.title || 'Folio 封面'}
                class="mb-3 aspect-square w-full rounded-xl border border-border/30 object-cover"
              />
            {/if}
            <Input
              id="folio-cover-{folio?.id ?? 'new'}"
              name="cover_file"
              type="file"
              accept="image/png"
              class="bg-background/50 border-border/40 focus-visible:ring-primary/20 rounded-xl"
            />
            <Field.FieldDescription class="text-xs text-muted-foreground/70 mt-1">
              PNG，最大 5 MB。{folio
                ? `保存为 folios/${folio.id}.png`
                : '创建后自动保存为 folios/{folio_id}.png'}
            </Field.FieldDescription>
          </Field.Field>
        </div>
        <div
          class="flex flex-wrap gap-8 border-y border-border/10 py-3 bg-secondary/15 rounded-xl px-4"
        >
          <Field.Field orientation="horizontal">
            <Checkbox
              id="folio-featured-{folio?.id ?? 'new'}"
              name="featured"
              checked={folio?.featured ?? false}
              class="border-border/60 data-[state=checked]:bg-primary rounded-md"
            />
            <Field.FieldLabel
              for="folio-featured-{folio?.id ?? 'new'}"
              class="text-sm font-medium select-none cursor-pointer"
            >
              设为精选 (Featured)
            </Field.FieldLabel>
          </Field.Field>
          <Field.Field orientation="horizontal">
            <Checkbox
              id="folio-public-{folio?.id ?? 'new'}"
              name="is_public"
              checked={folio?.is_public ?? false}
              class="border-border/60 data-[state=checked]:bg-primary rounded-md"
            />
            <Field.FieldLabel
              for="folio-public-{folio?.id ?? 'new'}"
              class="text-sm font-medium select-none cursor-pointer"
            >
              公开发布 (Public)
            </Field.FieldLabel>
          </Field.Field>
        </div>
        <div class="flex justify-end pt-1">
          <Button
            type="submit"
            class="rounded-full px-5 bg-primary text-primary-foreground hover:bg-primary/90 transition-all shadow-sm"
            disabled={submitting}
          >
            {#if submitting}
              <Spinner data-icon="inline-start" class="size-4 mr-1.5" />
            {:else}
              <Save data-icon="inline-start" class="size-4 mr-1.5" />
            {/if}
            {folio ? '保存核心关联' : '创建 Folio'}
          </Button>
        </div>
      </form>
      {#if folio}
        <Separator class="bg-border/40" />
        <h3
          class="text-[15px] font-medium text-foreground border-l-2 border-primary pl-2 leading-none pt-2"
        >
          双语内容编辑
        </h3>
        <div class="grid gap-6 lg:grid-cols-2">
          <div class="border border-border/30 bg-background/30 rounded-xl p-4 space-y-4">
            {@render FolioTranslation('中文内容 (Chinese)', 'zh', folio, zh, submitting, submit)}
          </div>
          <div class="border border-border/30 bg-background/30 rounded-xl p-4 space-y-4">
            {@render FolioTranslation('English content', 'en', folio, en, submitting, submit)}
          </div>
        </div>
        <Separator class="bg-border/40" />
        <h3
          class="text-[15px] font-medium text-foreground border-l-2 border-primary pl-2 leading-none pt-2"
        >
          关联主题 (Themes)
        </h3>
        <form method="POST" action="?/saveFolioThemes" use:enhance={submit} class="space-y-4">
          <input type="hidden" name="id" value={folio.id} />
          <Field.Field>
            <div
              class="grid gap-4 sm:grid-cols-2 xl:grid-cols-3 bg-background/30 border border-border/30 rounded-xl p-4"
            >
              {#each data.themes as theme (theme.id)}
                {@const name = translation(theme.themes_translations, 'zh')}
                <Field.Field orientation="horizontal" class="py-1">
                  <Checkbox
                    id="folio-{folio.id}-theme-{theme.id}"
                    name="theme_ids"
                    value={theme.id}
                    checked={selectedThemes.has(theme.id)}
                    class="border-border/60 data-[state=checked]:bg-primary rounded-md"
                  />
                  <Field.FieldLabel
                    for="folio-{folio.id}-theme-{theme.id}"
                    class="text-sm select-none cursor-pointer"
                  >
                    {name?.name || theme.key}
                    <span class="text-xs text-muted-foreground/60 font-mono ml-1"
                      >({theme.key})</span
                    >
                  </Field.FieldLabel>
                </Field.Field>
              {/each}
            </div>
          </Field.Field>
          <div class="flex justify-end">
            <Button type="submit" variant="outline" class="rounded-full px-5" disabled={submitting}>
              <Save data-icon="inline-start" class="size-4 mr-1.5" />
              保存关联主题
            </Button>
          </div>
        </form>
        <Separator class="bg-border/40" />
        <h3
          class="text-[15px] font-medium text-foreground border-l-2 border-primary pl-2 leading-none pt-2"
        >
          Agent 系统提示词 (System Prompt)
        </h3>
        <form method="POST" action="?/saveFolioPrompt" use:enhance={submit} class="space-y-4">
          <input type="hidden" name="id" value={folio.id} />
          <input type="hidden" name="prompt_id" value={prompt?.id ?? ''} />
          <Field.Field>
            <Textarea
              id="folio-prompt-{folio.id}"
              name="prompt"
              value={prompt?.content ?? ''}
              placeholder="配置用以引导该思想家模拟思辨的 Prompt..."
              rows={5}
              class="bg-background/50 border-border/40 focus-visible:ring-primary/20 rounded-xl text-sm leading-relaxed"
            />
            <Field.FieldDescription class="text-xs text-muted-foreground/70 mt-1">
              用来控制此 Folio 生成对应文章时，AI 扮演该思想家风格的 Prompt 设定。
            </Field.FieldDescription>
          </Field.Field>
          <div class="flex justify-end">
            <Button type="submit" variant="outline" class="rounded-full px-5" disabled={submitting}>
              <Save data-icon="inline-start" class="size-4 mr-1.5" />
              保存提示词
            </Button>
          </div>
        </form>
      {:else}
        <p class="text-sm text-muted-foreground/70">
          创建后可分别编辑中文、英文、关联主题与系统提示词。
        </p>
      {/if}
    </Card.Content>
    {#if folio}
      <Card.Footer class="border-t border-border/10 pt-5">
        <form method="POST" action="?/deleteFolio" use:enhance={submit}>
          <input type="hidden" name="id" value={folio.id} />
          <Button
            type="submit"
            variant="destructive"
            class="rounded-full px-5 hover:bg-destructive/95 transition-all shadow-sm"
            disabled={submitting}
            onclick={(event) => {
              if (!confirm('此操作不可撤销，确定删除？')) event.preventDefault();
            }}
          >
            <Trash2 data-icon="inline-start" class="size-4 mr-1.5" />
            删除 Folio
          </Button>
        </form>
      </Card.Footer>
    {/if}
  </Card.Root>
{/snippet}

{#snippet FolioTranslation(
  lang: string,
  suffix: string,
  folio: PageProps['data']['folios'][number] | undefined,
  values: { title: string; subtitle: string | null; description: string | null } | undefined,
  submitting: boolean,
  submit: SubmitFunction
)}
  <form method="POST" action="?/saveFolioTranslation" use:enhance={submit} class="space-y-4">
    <input type="hidden" name="id" value={folio?.id ?? ''} />
    <input type="hidden" name="lang" value={suffix} />
    <Field.FieldGroup class="space-y-4">
      <div class="flex items-center justify-between">
        <span class="text-sm font-semibold text-foreground">{lang}</span>
      </div>
      <Field.Field>
        <Field.FieldLabel
          for="folio-title-{suffix}-{folio?.id ?? 'new'}"
          class="text-xs font-medium text-muted-foreground">标题 (Title)</Field.FieldLabel
        >
        <Input
          id="folio-title-{suffix}-{folio?.id ?? 'new'}"
          name="title"
          value={values?.title ?? ''}
          placeholder={suffix === 'zh' ? '推石上山' : 'e.g. The Myth of Sisyphus'}
          class="bg-background/50 border-border/40 focus-visible:ring-primary/20 rounded-xl h-9 text-sm"
          required
        />
      </Field.Field>
      <Field.Field>
        <Field.FieldLabel
          for="folio-subtitle-{suffix}-{folio?.id ?? 'new'}"
          class="text-xs font-medium text-muted-foreground">副标题 (Subtitle)</Field.FieldLabel
        >
        <Input
          id="folio-subtitle-{suffix}-{folio?.id ?? 'new'}"
          name="subtitle"
          value={values?.subtitle ?? ''}
          placeholder={suffix === 'zh' ? '选填副标题...' : 'Optional subtitle...'}
          class="bg-background/50 border-border/40 focus-visible:ring-primary/20 rounded-xl h-9 text-sm"
        />
      </Field.Field>
      <Field.Field>
        <Field.FieldLabel
          for="folio-description-{suffix}-{folio?.id ?? 'new'}"
          class="text-xs font-medium text-muted-foreground"
          >引言与概要 (Description)</Field.FieldLabel
        >
        <Textarea
          id="folio-description-{suffix}-{folio?.id ?? 'new'}"
          name="description"
          value={values?.description ?? ''}
          placeholder={suffix === 'zh'
            ? '输入本思想卷的核心警句或主旨概要...'
            : 'Enter description...'}
          rows={6}
          class="bg-background/50 border-border/40 focus-visible:ring-primary/20 rounded-xl resize-y text-sm leading-relaxed"
        />
      </Field.Field>
      <div class="flex justify-end">
        <Button
          type="submit"
          variant="outline"
          size="sm"
          class="rounded-full px-4"
          disabled={submitting}
        >
          <Save data-icon="inline-start" class="size-3.5 mr-1" />
          保存{suffix === 'zh' ? '中文' : '英文'}
        </Button>
      </div>
    </Field.FieldGroup>
  </form>
{/snippet}

<style>
  .folio-serif {
    font-family: var(--font-serif), Georgia, 'Times New Roman', serif;
  }
</style>
