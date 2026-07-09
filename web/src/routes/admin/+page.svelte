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
  let selectedSoulerId = $state<string | null>(null);
  let submitting = $state(false);

  const submit: SubmitFunction = () => {
    submitting = true;
    return async ({ update }) => {
      await update();
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
  const selectedSouler = $derived(data.soulers.find((souler) => souler.id === selectedSoulerId));
</script>

<svelte:head>
  <title>内容管理 | Folio</title>
  <meta name="description" content="管理 Folio 的主题、思想家与内容。" />
</svelte:head>

<main class="min-h-screen bg-muted/20 text-foreground">
  <header class="sticky top-0 border-b bg-background/90 backdrop-blur">
    <div class="mx-auto flex h-16 max-w-7xl items-center gap-3 px-4 sm:px-6">
      <Button variant="ghost" size="icon-sm" href={resolve('/')} aria-label="返回首页">
        <ArrowLeft />
      </Button>
      <div class="min-w-0 flex-1">
        <h1 class="folio-serif text-xl font-semibold">Folio Admin</h1>
        <p class="text-xs text-muted-foreground">内容与关联管理</p>
      </div>
      <ThemeToggle />
      <form method="POST" action="/auth/signout">
        <Button type="submit" variant="ghost" size="icon-sm" aria-label="退出登录">
          <LogOut />
        </Button>
      </form>
    </div>
  </header>

  <div class="mx-auto grid max-w-7xl gap-6 px-4 py-6 sm:px-6 lg:grid-cols-[220px_1fr]">
    <aside>
      <nav class="flex gap-2 overflow-x-auto lg:sticky lg:top-22 lg:flex-col">
        {#each sections as item (item.key)}
          {@const Icon = item.icon}
          <Button
            type="button"
            variant={section === item.key ? 'secondary' : 'ghost'}
            class="justify-start"
            onclick={() => (section = item.key)}
          >
            <Icon data-icon="inline-start" />
            {item.label}
            <Badge class="ml-auto" variant="outline">{item.count}</Badge>
          </Button>
        {/each}
      </nav>
    </aside>

    <section class="min-w-0">
      {#if form?.message}
        <Alert.Root class="mb-5" variant={form.success ? 'default' : 'destructive'}>
          {#if form.success}
            <CircleCheck />
          {:else}
            <CircleAlert />
          {/if}
          <Alert.Title>{form.success ? '操作完成' : '操作失败'}</Alert.Title>
          <Alert.Description>{form.message}</Alert.Description>
        </Alert.Root>
      {/if}

      {#if section === 'themes'}
        <div class="flex flex-col gap-5">
          {@render PageHeading('Themes', '维护稳定 key 与中英文名称。')}
          {@render ThemeForm(undefined, submitting, submit)}
          {#each data.themes as theme (theme.id)}
            {@render ThemeForm(theme, submitting, submit)}
          {/each}
        </div>
      {:else if section === 'soulers'}
        <div class="flex flex-col gap-5">
          {@render PageHeading('Soulers', '审核人物，并按语言独立维护资料。')}
          {@render CreateSouler(submitting, submit)}
          <div class="grid items-start gap-5 xl:grid-cols-[320px_1fr]">
            <div class="flex flex-col gap-5">
              {@render SoulerList('待审核', pendingSoulers, 'Agent 生成后等待人工确认')}
              {@render SoulerList('已审核', approvedSoulers, '已确认可用于正式内容')}
            </div>
            {#if selectedSouler}
              {@render SoulerDetails(selectedSouler, submitting, submit)}
            {:else}
              <Card.Root>
                <Card.Header>
                  <Card.Title>选择人物</Card.Title>
                  <Card.Description>点击左侧人物名查看并编辑详细资料。</Card.Description>
                </Card.Header>
              </Card.Root>
            {/if}
          </div>
        </div>
      {:else}
        <div class="flex flex-col gap-5">
          {@render PageHeading('Folios', '维护双语内容，并关联 Souler 与 Themes。')}
          {@render FolioForm(data, undefined, submitting, submit)}
          {#each data.folios as folio (folio.id)}
            {@render FolioForm(data, folio, submitting, submit)}
          {/each}
        </div>
      {/if}
    </section>
  </div>
</main>

{#snippet PageHeading(title: string, description: string)}
  <div>
    <h2 class="folio-serif text-3xl font-semibold">{title}</h2>
    <p class="mt-1 text-sm text-muted-foreground">{description}</p>
  </div>
{/snippet}

{#snippet Actions(id: string | undefined, deleteAction: string, submitting: boolean)}
  <div class="flex items-center justify-between gap-3">
    {#if id}
      <Button
        type="submit"
        variant="destructive"
        size="sm"
        formaction={deleteAction}
        onclick={(event) => {
          if (!confirm('此操作不可撤销，确定删除？')) event.preventDefault();
        }}
      >
        <Trash2 data-icon="inline-start" />
        删除
      </Button>
    {:else}
      <span></span>
    {/if}
    <Button type="submit" size="sm" disabled={submitting}>
      {#if submitting}
        <Spinner data-icon="inline-start" />
      {:else if id}
        <Save data-icon="inline-start" />
      {:else}
        <Plus data-icon="inline-start" />
      {/if}
      {id ? '保存' : '新建'}
    </Button>
  </div>
{/snippet}

{#snippet ThemeForm(
  theme: PageProps['data']['themes'][number] | undefined = undefined,
  submitting: boolean,
  submit: SubmitFunction
)}
  {@const zh = translation(theme?.themes_translations ?? null, 'zh')}
  {@const en = translation(theme?.themes_translations ?? null, 'en')}
  <Card.Root>
    <Card.Header>
      <Card.Title>{theme ? zh?.name || theme.key : '新建 Theme'}</Card.Title>
      <Card.Description>{theme?.key || '创建一个可复用的内容主题'}</Card.Description>
    </Card.Header>
    <form method="POST" action="?/saveTheme" use:enhance={submit}>
      <Card.Content>
        <input type="hidden" name="id" value={theme?.id ?? ''} />
        <Field.FieldGroup>
          <Field.Field>
            <Field.FieldLabel for="theme-key-{theme?.id ?? 'new'}">Key</Field.FieldLabel>
            <Input
              id="theme-key-{theme?.id ?? 'new'}"
              name="key"
              value={theme?.key ?? ''}
              required
            />
            <Field.FieldDescription>稳定的小写标识，例如 existentialism。</Field.FieldDescription>
          </Field.Field>
          <div class="grid gap-4 sm:grid-cols-2">
            <Field.Field>
              <Field.FieldLabel for="theme-zh-{theme?.id ?? 'new'}">中文名称</Field.FieldLabel>
              <Input
                id="theme-zh-{theme?.id ?? 'new'}"
                name="name_zh"
                value={zh?.name ?? ''}
                required
              />
            </Field.Field>
            <Field.Field>
              <Field.FieldLabel for="theme-en-{theme?.id ?? 'new'}">English name</Field.FieldLabel>
              <Input
                id="theme-en-{theme?.id ?? 'new'}"
                name="name_en"
                value={en?.name ?? ''}
                required
              />
            </Field.Field>
          </div>
        </Field.FieldGroup>
      </Card.Content>
      <Card.Footer class="mt-5 block">
        {@render Actions(theme?.id, '?/deleteTheme', submitting)}
      </Card.Footer>
    </form>
  </Card.Root>
{/snippet}

{#snippet CreateSouler(submitting: boolean, submit: SubmitFunction)}
  <Card.Root>
    <Card.Header>
      <Card.Title>新建人物</Card.Title>
      <Card.Description>提交姓名与原始语言，资料将由 Agent 经 Taskiq 后台生成。</Card.Description>
    </Card.Header>
    <form method="POST" action="?/createSouler" use:enhance={submit}>
      <Card.Content>
        <Field.FieldGroup>
          <div class="grid gap-4 sm:grid-cols-[1fr_180px]">
            <Field.Field>
              <Field.FieldLabel for="new-souler-name">人物名</Field.FieldLabel>
              <Input id="new-souler-name" name="name" required />
            </Field.Field>
            <Field.Field>
              <Field.FieldLabel for="new-souler-lang">语言</Field.FieldLabel>
              <select
                id="new-souler-lang"
                name="lang"
                class="h-9 w-full rounded-md border bg-transparent px-3 text-sm"
                required
              >
                <option value="zh">中文</option>
                <option value="en">English</option>
              </select>
            </Field.Field>
          </div>
        </Field.FieldGroup>
      </Card.Content>
      <Card.Footer class="mt-5 justify-end">
        <Button type="submit" size="sm" disabled={submitting}>
          {#if submitting}
            <Spinner data-icon="inline-start" />
          {:else}
            <Plus data-icon="inline-start" />
          {/if}
          提交创建
        </Button>
      </Card.Footer>
    </form>
  </Card.Root>
{/snippet}

{#snippet SoulerList(title: string, soulers: PageProps['data']['soulers'], description: string)}
  <Card.Root>
    <Card.Header>
      <div class="flex items-center justify-between gap-3">
        <Card.Title>{title}</Card.Title>
        <Badge variant="secondary">{soulers.length}</Badge>
      </div>
      <Card.Description>{description}</Card.Description>
    </Card.Header>
    <Card.Content class="flex flex-col gap-1">
      {#each soulers as souler (souler.id)}
        {@const zh = translation(souler.souler_profile, 'zh')}
        {@const en = translation(souler.souler_profile, 'en')}
        {@const name = zh?.name || en?.name || souler.wiki_id || '未命名人物'}
        <Button
          type="button"
          variant={selectedSoulerId === souler.id ? 'secondary' : 'ghost'}
          class="h-auto justify-start py-2"
          onclick={() => (selectedSoulerId = souler.id)}
        >
          <Avatar.Root class="size-8">
            {#if souler.avatar}
              <Avatar.Image src={souler.avatar} alt={name} />
            {/if}
            <Avatar.Fallback>{name.slice(0, 1)}</Avatar.Fallback>
          </Avatar.Root>
          <span class="min-w-0 flex-1 truncate text-left">{name}</span>
          <ChevronRight />
        </Button>
      {:else}
        <p class="py-4 text-center text-sm text-muted-foreground">暂无人物</p>
      {/each}
    </Card.Content>
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
  <Card.Root>
    <Card.Header>
      <div class="flex items-start justify-between gap-3">
        <div>
          <Card.Title>{displayName}</Card.Title>
          <Card.Description>{souler.wiki_id || souler.id}</Card.Description>
        </div>
        <Badge variant={souler.checked ? 'default' : 'outline'}>
          {souler.checked ? '已审核' : '待审核'}
        </Badge>
      </div>
    </Card.Header>
    <form method="POST" action="?/saveSoulerBase" use:enhance={submit}>
      <Card.Content>
        <input type="hidden" name="id" value={souler.id} />
        <Field.FieldGroup>
          <div class="grid gap-4 sm:grid-cols-2">
            <Field.Field>
              <Field.FieldLabel for="souler-wiki-{souler.id}">Wiki ID</Field.FieldLabel>
              <Input id="souler-wiki-{souler.id}" name="wiki_id" value={souler.wiki_id ?? ''} />
            </Field.Field>
            <Field.Field>
              <Field.FieldLabel for="souler-avatar-{souler.id}">Avatar URL</Field.FieldLabel>
              <Input id="souler-avatar-{souler.id}" name="avatar" value={souler.avatar ?? ''} />
            </Field.Field>
          </div>
          <Field.Field orientation="horizontal">
            <Checkbox id="souler-checked-{souler.id}" name="checked" checked={souler.checked} />
            <Field.FieldLabel for="souler-checked-{souler.id}">资料已审核</Field.FieldLabel>
          </Field.Field>
          <Field.Field>
            <Field.FieldLabel for="souler-aliases-{souler.id}">Aliases</Field.FieldLabel>
            <Textarea
              id="souler-aliases-{souler.id}"
              name="aliases"
              value={souler.souler_aliases?.map((item) => item.alias).join('\n') ?? ''}
            />
            <Field.FieldDescription>每行一个别名。</Field.FieldDescription>
          </Field.Field>
        </Field.FieldGroup>
      </Card.Content>
      <Card.Footer class="mt-5 justify-end">
        <Button type="submit" size="sm" disabled={submitting}>
          {#if submitting}<Spinner data-icon="inline-start" />{:else}<Save
              data-icon="inline-start"
            />{/if}
          保存基础资料
        </Button>
      </Card.Footer>
    </form>
    <Separator />
    <Card.Content class="grid gap-5 pt-6 lg:grid-cols-2">
      {@render SoulerProfile(souler.id, 'zh', '中文资料', zh, submitting, submit)}
      {@render SoulerProfile(souler.id, 'en', 'English profile', en, submitting, submit)}
    </Card.Content>
    <Card.Footer class="justify-start">
      <form method="POST" action="?/deleteSouler" use:enhance={submit}>
        <input type="hidden" name="id" value={souler.id} />
        <Button
          type="submit"
          variant="destructive"
          size="sm"
          disabled={submitting}
          onclick={(event) => {
            if (!confirm('此操作不可撤销，确定删除？')) event.preventDefault();
          }}
        >
          <Trash2 data-icon="inline-start" />
          删除人物
        </Button>
      </form>
    </Card.Footer>
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
  <form method="POST" action="?/saveSoulerProfile" use:enhance={submit}>
    <input type="hidden" name="id" value={soulerId} />
    <input type="hidden" name="lang" value={lang} />
    <Field.FieldGroup>
      <h3 class="text-sm font-medium">{title}</h3>
      <Field.Field>
        <Field.FieldLabel for="souler-name-{lang}-{soulerId}">姓名</Field.FieldLabel>
        <Input
          id="souler-name-{lang}-{soulerId}"
          name="name"
          value={profile?.name ?? ''}
          required
        />
      </Field.Field>
      <Field.Field>
        <Field.FieldLabel for="souler-introduction-{lang}-{soulerId}">介绍</Field.FieldLabel>
        <Textarea
          id="souler-introduction-{lang}-{soulerId}"
          name="introduction"
          value={profile?.introduction ?? ''}
          rows={8}
        />
      </Field.Field>
      <div class="flex justify-end">
        <Button type="submit" variant="outline" size="sm" disabled={submitting}>
          {#if submitting}<Spinner data-icon="inline-start" />{:else}<Save
              data-icon="inline-start"
            />{/if}
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
  submit: SubmitFunction
)}
  {@const zh = translation(folio?.folio_translations ?? null, 'zh')}
  {@const en = translation(folio?.folio_translations ?? null, 'en')}
  {@const prompt = activePrompt(folio?.folio_prompts ?? null)}
  {@const selectedThemes = new Set(folio?.folio_themes?.map((item) => item.theme_id) ?? [])}
  <Card.Root>
    <Card.Header>
      <Card.Title>{folio ? zh?.title || en?.title || '未命名 Folio' : '新建 Folio'}</Card.Title>
      <Card.Description
        >{folio ? (folio.is_public ? '已发布' : '草稿') : '创建一份新的双语内容'}</Card.Description
      >
    </Card.Header>
    <form method="POST" action="?/saveFolio" use:enhance={submit}>
      <Card.Content>
        <input type="hidden" name="id" value={folio?.id ?? ''} />
        <input type="hidden" name="prompt_id" value={prompt?.id ?? ''} />
        <Field.FieldGroup>
          <div class="grid gap-4 sm:grid-cols-2">
            <Field.Field>
              <Field.FieldLabel for="folio-souler-{folio?.id ?? 'new'}">Souler</Field.FieldLabel>
              <select
                id="folio-souler-{folio?.id ?? 'new'}"
                name="souler_id"
                class="h-9 w-full rounded-md border bg-transparent px-3 text-sm"
                required
              >
                <option value="">请选择</option>
                {#each data.soulers as souler (souler.id)}
                  {@const profile = translation(souler.souler_profile, 'zh')}
                  <option value={souler.id} selected={souler.id === folio?.souler_id}>
                    {profile?.name || souler.wiki_id || souler.id}
                  </option>
                {/each}
              </select>
            </Field.Field>
            <Field.Field>
              <Field.FieldLabel for="folio-cover-{folio?.id ?? 'new'}"
                >Cover image URL</Field.FieldLabel
              >
              <Input
                id="folio-cover-{folio?.id ?? 'new'}"
                name="cover_image"
                value={folio?.cover_image ?? ''}
              />
            </Field.Field>
          </div>
          <div class="flex flex-wrap gap-6">
            <Field.Field orientation="horizontal">
              <Checkbox
                id="folio-featured-{folio?.id ?? 'new'}"
                name="featured"
                checked={folio?.featured ?? false}
              />
              <Field.FieldLabel for="folio-featured-{folio?.id ?? 'new'}">精选</Field.FieldLabel>
            </Field.Field>
            <Field.Field orientation="horizontal">
              <Checkbox
                id="folio-public-{folio?.id ?? 'new'}"
                name="is_public"
                checked={folio?.is_public ?? false}
              />
              <Field.FieldLabel for="folio-public-{folio?.id ?? 'new'}">公开发布</Field.FieldLabel>
            </Field.Field>
          </div>
          <Separator />
          <div class="grid gap-4 lg:grid-cols-2">
            {@render FolioTranslation('中文', 'zh', folio, zh)}
            {@render FolioTranslation('English', 'en', folio, en)}
          </div>
          <Field.Field>
            <Field.FieldLabel>Themes</Field.FieldLabel>
            <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
              {#each data.themes as theme (theme.id)}
                {@const name = translation(theme.themes_translations, 'zh')}
                <Field.Field orientation="horizontal">
                  <Checkbox
                    id="folio-{folio?.id ?? 'new'}-theme-{theme.id}"
                    name="theme_ids"
                    value={theme.id}
                    checked={selectedThemes.has(theme.id)}
                  />
                  <Field.FieldLabel for="folio-{folio?.id ?? 'new'}-theme-{theme.id}">
                    {name?.name || theme.key}
                  </Field.FieldLabel>
                </Field.Field>
              {/each}
            </div>
          </Field.Field>
          <Field.Field>
            <Field.FieldLabel for="folio-prompt-{folio?.id ?? 'new'}"
              >Active prompt</Field.FieldLabel
            >
            <Textarea
              id="folio-prompt-{folio?.id ?? 'new'}"
              name="prompt"
              value={prompt?.content ?? ''}
              rows={6}
            />
          </Field.Field>
        </Field.FieldGroup>
      </Card.Content>
      <Card.Footer class="mt-5 block">
        {@render Actions(folio?.id, '?/deleteFolio', submitting)}
      </Card.Footer>
    </form>
  </Card.Root>
{/snippet}

{#snippet FolioTranslation(
  lang: string,
  suffix: string,
  folio: PageProps['data']['folios'][number] | undefined,
  values: { title: string; subtitle: string | null; description: string | null } | undefined
)}
  <Field.FieldGroup>
    <h3 class="text-sm font-medium">{lang}</h3>
    <Field.Field>
      <Field.FieldLabel for="folio-title-{suffix}-{folio?.id ?? 'new'}">Title</Field.FieldLabel>
      <Input
        id="folio-title-{suffix}-{folio?.id ?? 'new'}"
        name="title_{suffix}"
        value={values?.title ?? ''}
        required
      />
    </Field.Field>
    <Field.Field>
      <Field.FieldLabel for="folio-subtitle-{suffix}-{folio?.id ?? 'new'}"
        >Subtitle</Field.FieldLabel
      >
      <Input
        id="folio-subtitle-{suffix}-{folio?.id ?? 'new'}"
        name="subtitle_{suffix}"
        value={values?.subtitle ?? ''}
      />
    </Field.Field>
    <Field.Field>
      <Field.FieldLabel for="folio-description-{suffix}-{folio?.id ?? 'new'}"
        >Description</Field.FieldLabel
      >
      <Textarea
        id="folio-description-{suffix}-{folio?.id ?? 'new'}"
        name="description_{suffix}"
        value={values?.description ?? ''}
      />
    </Field.Field>
  </Field.FieldGroup>
{/snippet}
