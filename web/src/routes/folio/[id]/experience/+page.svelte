<script lang="ts">
  import { resolve } from '$app/paths';
  import { Button } from '$lib/components/ui/button';
  import { Textarea } from '$lib/components/ui/textarea';
  import ThemeToggle from '$lib/components/theme-toggle.svelte';
  import ArrowLeft from '@lucide/svelte/icons/arrow-left';
  import ArrowUp from '@lucide/svelte/icons/arrow-up';
  import { onMount } from 'svelte';
  import type { PageProps } from './$types';

  type Message = {
    id: string;
    role: 'user' | 'assistant';
    content: string;
  };

  type StreamEvent =
    | { type: 'ready'; sessionId: string }
    | { type: 'delta'; delta: string }
    | { type: 'options'; options: string[] }
    | { type: 'done'; sessionId: string; ended: boolean }
    | { type: 'error'; message: string };

  let { data }: PageProps = $props();
  const folio = $derived(data.folio);

  let messages = $state<Message[]>([]);
  let options = $state<string[]>([]);
  let sessionId = $state<string | null>(null);
  let draft = $state('');
  let isStreaming = $state(true);
  let isEnded = $state(false);
  let requestError = $state<string | null>(null);

  let chatEndEl = $state<HTMLElement | null>(null);

  onMount(() => {
    void streamReply('start');
  });

  $effect(() => {
    // Scroll to bottom when messages length changes (new user or assistant message bubble)
    const len = messages.length;
    if (len > 0) {
      chatEndEl?.scrollIntoView({ behavior: 'smooth' });
    }
  });

  async function streamReply(action: 'start' | 'messages', content?: string) {
    isStreaming = true;
    requestError = null;
    options = [];

    if (content) {
      messages.push({ id: crypto.randomUUID(), role: 'user', content });
    }
    const assistantMessage: Message = {
      id: crypto.randomUUID(),
      role: 'assistant',
      content: ''
    };
    messages.push(assistantMessage);
    const activeAssistantMessage = messages[messages.length - 1];

    try {
      const response = await fetch(`/api/folio/${folio.id}/${action}`, {
        method: 'POST',
        headers: action === 'messages' ? { 'Content-Type': 'application/json' } : undefined,
        body: action === 'messages' ? JSON.stringify({ sessionId, content }) : undefined
      });
      if (!response.ok || !response.body) {
        const body = (await response.json().catch(() => null)) as { message?: string } | null;
        throw new Error(body?.message ?? '体验暂时无法继续。');
      }

      await consumeStream(response.body, (event) => {
        if (event.type === 'ready') {
          sessionId = event.sessionId;
        } else if (event.type === 'delta') {
          activeAssistantMessage.content += event.delta;
        } else if (event.type === 'options') {
          options = event.options;
        } else if (event.type === 'done') {
          sessionId = event.sessionId;
          isEnded = event.ended;
        } else if (event.type === 'error') {
          throw new Error(event.message);
        }
      });
    } catch (error) {
      messages = messages.filter((message) => message.id !== activeAssistantMessage.id);
      requestError = error instanceof Error ? error.message : '体验暂时无法继续。';
    } finally {
      isStreaming = false;
    }
  }

  async function consumeStream(
    stream: ReadableStream<Uint8Array>,
    onEvent: (event: StreamEvent) => void
  ) {
    const reader = stream.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    while (true) {
      const { done, value } = await reader.read();
      buffer += decoder.decode(value, { stream: !done });
      const events = buffer.split('\n\n');
      buffer = events.pop() ?? '';

      for (const entry of events) {
        const line = entry.split('\n').find((item) => item.startsWith('data: '));
        if (line) onEvent(JSON.parse(line.slice(6)) as StreamEvent);
      }
      if (done) break;
    }
  }

  function send(content: string) {
    const normalized = content.trim();
    if (!normalized || isStreaming || isEnded || !sessionId) return;
    draft = '';
    void streamReply('messages', normalized);
  }
</script>

<svelte:head>
  <title>{folio.title} | Folio 体验</title>
</svelte:head>

<main class="min-h-screen bg-background text-foreground relative pb-40">
  <!-- Ambient decorative background glows -->
  <div class="pointer-events-none fixed inset-0 -z-10 overflow-hidden">
    <div
      class="absolute -left-1/4 top-1/4 h-[500px] w-[500px] rounded-full bg-accent/20 blur-3xl opacity-60 dark:opacity-30 transition-all duration-1000"
    ></div>
    <div
      class="absolute -right-1/4 top-1/3 h-[600px] w-[600px] rounded-full bg-secondary/60 blur-3xl opacity-40 dark:opacity-20 transition-all duration-1000"
    ></div>
  </div>

  <header class="sticky top-0 z-10 border-b border-border/30 bg-background/85 backdrop-blur-md">
    <div class="mx-auto flex h-16 max-w-3xl items-center justify-between px-5 sm:px-8">
      <div class="flex items-center gap-4 min-w-0">
        <Button
          variant="ghost"
          size="icon"
          href={resolve(`/folio/${folio.id}`)}
          class="rounded-full border border-border/20 bg-background/40 hover:bg-background/80 transition-all duration-300 hover:scale-105 active:scale-95"
          aria-label="返回 Folio"
        >
          <ArrowLeft class="size-5" />
        </Button>
        <span class="font-serif font-semibold text-lg tracking-wide truncate">{folio.title}</span>
      </div>
      <ThemeToggle />
    </div>
  </header>

  <div class="mx-auto flex min-h-[calc(100vh-4rem)] max-w-2xl flex-col px-5 pt-10 sm:px-8">
    <section class="flex-1 space-y-9" aria-live="polite">
      {#each messages as message (message.id)}
        {#if message.role === 'user'}
          <!-- User thoughts block -->
          <div class="flex flex-col items-end gap-1 animate-fade-in-up">
            <span class="font-sans text-[11px] font-medium tracking-wider text-muted-foreground/60 uppercase">你</span>
            <div
              class="max-w-[85%] rounded-2xl rounded-tr-xs border border-border/40 bg-secondary/40 dark:bg-secondary/20 px-5 py-3.5 text-sm leading-relaxed text-foreground/90 shadow-2xs"
            >
              {message.content}
            </div>
          </div>
        {:else if message.content}
          <!-- Assistant text block -->
          <article
            class="font-serif max-w-2xl whitespace-pre-wrap text-[17px] leading-[1.85] text-foreground/90 sm:text-lg sm:leading-[1.95] animate-fade-in-up"
          >
            {message.content}
          </article>
        {:else if isStreaming}
          <!-- Pulse loader -->
          <div class="flex items-center gap-2.5 py-4 text-muted-foreground/50 animate-fade-in" aria-label="正在生成">
            <div class="flex gap-1.5">
              <span class="size-1.5 rounded-full bg-muted-foreground/40 animate-pulse"></span>
              <span class="size-1.5 rounded-full bg-muted-foreground/40 animate-pulse [animation-delay:200ms]"></span>
              <span class="size-1.5 rounded-full bg-muted-foreground/40 animate-pulse [animation-delay:400ms]"></span>
            </div>
            <span class="font-serif text-xs italic tracking-wider">正在引导思绪...</span>
          </div>
        {/if}
      {/each}

      {#if requestError}
        <div class="rounded-xl border border-destructive/20 bg-destructive/5 px-4 py-3 text-sm text-destructive animate-fade-in-up">
          {requestError}
        </div>
      {/if}

      <div bind:this={chatEndEl} class="h-2"></div>
    </section>

    {#if options.length > 0 && !isStreaming}
      <!-- Option links/paths selection -->
      <div class="mt-12 grid gap-3.5 animate-fade-in-up">
        <div class="flex items-center gap-2">
          <div class="h-px flex-1 bg-border/20"></div>
          <span class="font-serif text-[11px] italic tracking-wider text-muted-foreground/50">选择你的回应</span>
          <div class="h-px flex-1 bg-border/20"></div>
        </div>
        <div class="grid gap-3">
          {#each options as option, index (option)}
            <Button
              variant="outline"
              class="h-auto justify-start items-start gap-4 whitespace-normal rounded-2xl border border-border/45 bg-card/45 hover:bg-accent/40 hover:border-primary/20 dark:hover:border-primary/30 px-5 py-4 text-left font-serif text-[15px] leading-relaxed text-foreground/85 transition-all duration-300 hover:-translate-y-0.5 hover:shadow-xs group"
              onclick={() => send(option)}
            >
              <span class="inline-flex size-5 shrink-0 items-center justify-center rounded-full bg-muted text-[10px] text-muted-foreground/80 font-sans group-hover:bg-primary group-hover:text-primary-foreground transition-all duration-300">
                {index + 1}
              </span>
              <span class="flex-1 leading-normal">{option}</span>
            </Button>
          {/each}
        </div>
      </div>
    {/if}

    {#if isEnded}
      <!-- Ended page view -->
      <div class="mt-16 flex flex-col items-center gap-4 text-center animate-fade-in-up">
        <div class="h-px w-24 bg-border/40"></div>
        <p class="font-serif text-base italic text-muted-foreground/80">本次思想漫步已结束</p>
        <p class="text-xs text-muted-foreground/50 max-w-xs leading-normal">
          思绪在文字间流转，化作心底的余音。你可以随时返回或开启新的旅程。
        </p>
        <Button
          variant="outline"
          class="mt-2 rounded-full px-6 border-border/40 hover:bg-accent/40 font-serif text-sm transition-all"
          href={resolve(`/folio/${folio.id}`)}
        >
          返回 Folio 页面
        </Button>
      </div>
    {/if}
  </div>

  {#if !isEnded}
    <!-- Input box floating island -->
    <div class="fixed bottom-6 left-1/2 -translate-x-1/2 w-[calc(100%-2rem)] sm:w-[calc(100%-4rem)] max-w-2xl z-40">
      <form
        class="w-full rounded-2xl border border-border/40 bg-background/85 backdrop-blur-md p-2.5 shadow-lg transition-all duration-300 hover:border-border/60 focus-within:border-primary/30 focus-within:shadow-xl animate-fade-in-up"
        onsubmit={(event) => {
          event.preventDefault();
          send(draft);
        }}
      >
        <div class="flex items-end gap-3">
          <Textarea
            bind:value={draft}
            rows={1}
            placeholder="倾听内心的声音，写下你的回应..."
            disabled={isStreaming || !sessionId}
            class="max-h-32 min-h-[40px] resize-none border-0 bg-transparent shadow-none focus-visible:ring-0 font-serif text-[15px] leading-relaxed placeholder:text-muted-foreground/45 py-2 px-2.5 flex-1"
          />
          <Button
            type="submit"
            size="icon"
            disabled={isStreaming || !sessionId || !draft.trim()}
            class="rounded-full size-10 shrink-0 bg-primary text-primary-foreground hover:scale-105 active:scale-95 transition-all duration-300 shadow-sm disabled:opacity-50 disabled:hover:scale-100"
            aria-label="发送"
          >
            <ArrowUp class="size-5" />
          </Button>
        </div>
      </form>
    </div>
  {/if}
</main>

<style>
  @keyframes fadeInUp {
    from {
      opacity: 0;
      transform: translateY(16px);
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
    animation: fadeInUp 0.8s cubic-bezier(0.16, 1, 0.3, 1) both;
  }

  .animate-fade-in {
    animation: fadeIn 0.8s cubic-bezier(0.16, 1, 0.3, 1) both;
  }
</style>
