<script lang="ts">
  import { resolve } from '$app/paths';
  import { Button } from '$lib/components/ui/button';
  import { Textarea } from '$lib/components/ui/textarea';
  import ArrowLeft from '@lucide/svelte/icons/arrow-left';
  import ArrowUp from '@lucide/svelte/icons/arrow-up';
  import LoaderCircle from '@lucide/svelte/icons/loader-circle';
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

  onMount(() => {
    void streamReply('start');
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
  <title>{folio.title} | Folio</title>
</svelte:head>

<main class="min-h-screen bg-background text-foreground">
  <header class="sticky top-0 z-10 border-b border-border/45 bg-background/90 backdrop-blur">
    <div class="mx-auto flex h-16 max-w-3xl items-center gap-4 px-5 sm:px-8">
      <Button
        variant="ghost"
        size="icon"
        href={resolve(`/folio/${folio.id}`)}
        aria-label="返回 Folio"
      >
        <ArrowLeft class="size-5" />
      </Button>
      <p class="folio-serif min-w-0 truncate text-lg">{folio.title}</p>
    </div>
  </header>

  <div class="mx-auto flex min-h-[calc(100vh-4rem)] max-w-3xl flex-col px-5 pb-32 pt-10 sm:px-8">
    <section class="flex-1 space-y-7" aria-live="polite">
      {#each messages as message (message.id)}
        {#if message.role === 'user'}
          <div
            class="ml-auto max-w-[85%] rounded-2xl rounded-br-md bg-primary px-4 py-3 text-sm leading-7 text-primary-foreground"
          >
            {message.content}
          </div>
        {:else if message.content}
          <article
            class="folio-serif max-w-2xl whitespace-pre-wrap text-lg leading-9 text-foreground/90 sm:text-xl sm:leading-10"
          >
            {message.content}
          </article>
        {:else if isStreaming}
          <LoaderCircle class="size-5 animate-spin text-muted-foreground" aria-label="正在生成" />
        {/if}
      {/each}

      {#if requestError}
        <p class="text-sm text-destructive">{requestError}</p>
      {/if}
    </section>

    {#if options.length > 0 && !isStreaming}
      <div class="mt-10 grid gap-3">
        {#each options as option (option)}
          <Button
            variant="outline"
            class="h-auto justify-start whitespace-normal rounded-xl px-4 py-3 text-left text-sm leading-6"
            onclick={() => send(option)}
          >
            {option}
          </Button>
        {/each}
      </div>
    {/if}

    {#if !isEnded}
      <form
        class="sticky bottom-0 mt-6 border-t border-border/45 bg-background py-5"
        onsubmit={(event) => {
          event.preventDefault();
          send(draft);
        }}
      >
        <div class="flex items-end gap-3 rounded-xl border border-border bg-card p-2 shadow-sm">
          <Textarea
            bind:value={draft}
            rows={1}
            placeholder="写下你的回应"
            disabled={isStreaming || !sessionId}
            class="max-h-32 min-h-10 resize-none border-0 bg-transparent shadow-none focus-visible:ring-0"
          />
          <Button
            type="submit"
            size="icon"
            disabled={isStreaming || !sessionId || !draft.trim()}
            aria-label="发送"
          >
            <ArrowUp class="size-4" />
          </Button>
        </div>
      </form>
    {:else}
      <p class="mt-10 text-center text-sm text-muted-foreground">本次体验已结束</p>
    {/if}
  </div>
</main>

<style>
  .folio-serif {
    font-family: Georgia, 'Times New Roman', serif;
  }
</style>
