import {
  applyQwenNoThinking,
  openai,
  getQwenModel,
} from "../_shared/openai.ts";
import { supabase } from "../_shared/supabase.ts";
import {
  extractSoulerId,
  isRecord,
  jsonResponse,
  type Json,
  truncateError,
} from "../_shared/webhook.ts";
import {
  GENERATION_SYSTEM_PROMPT_EN,
  GENERATION_SYSTEM_PROMPT_ZH,
} from "./prompts.ts";

type ChatMessage = { role: "system" | "user"; content: string };

type Chapter = {
  title: string;
  subtitle: string;
  task: string;
};

const QWEN_MODEL = getQwenModel();
const CHAPTERS_TEMPERATURE = 0.35;
const MIN_CHAPTER_COUNT = 5;
const MAX_CHAPTER_COUNT = 15;
const MODEL_TIMEOUT_MS = 60_000;

const CHAPTER_SCHEMA: Json = {
  type: "object",
  properties: {
    chapters: {
      type: "array",
      minItems: MIN_CHAPTER_COUNT,
      maxItems: MAX_CHAPTER_COUNT,
      items: {
        type: "object",
        properties: {
          title: { type: "string" },
          subtitle: { type: "string" },
          task: { type: "string" },
        },
        required: ["title", "subtitle", "task"],
        additionalProperties: false,
      },
    },
  },
  required: ["chapters"],
  additionalProperties: false,
};

const buildChapterMessages = (soulerName: string, lang: string): ChatMessage[] => {
  const prompt = lang === "zh" ? GENERATION_SYSTEM_PROMPT_ZH : GENERATION_SYSTEM_PROMPT_EN;

  return [
    {
      role: "system",
      content: prompt,
    },
    { role: "user", content: soulerName },
  ];
};

const completeJson = async (messages: ChatMessage[]): Promise<unknown> => {
  const requestBody = applyQwenNoThinking(QWEN_MODEL, {
    model: QWEN_MODEL,
    messages,
    temperature: CHAPTERS_TEMPERATURE,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "souler_chapters",
        strict: true,
        schema: CHAPTER_SCHEMA,
      },
    },
  });

  const completion = await openai.chat.completions.create(
    requestBody as never,
    { timeout: MODEL_TIMEOUT_MS } as never,
  );
  const content = completion.choices?.[0]?.message?.content;
  const text = typeof content === "string" ? content.trim() : "";
  if (!text) {
    throw new Error("Model returned empty chapters payload");
  }

  try {
    return JSON.parse(text);
  } catch {
    throw new Error("Model returned non-JSON chapters payload");
  }
};

const normalizeChapter = (value: unknown): Chapter => {
  if (!isRecord(value)) {
    throw new Error("Invalid chapter item");
  }

  const title = typeof value.title === "string" ? value.title.trim() : "";
  const subtitle = typeof value.subtitle === "string" ? value.subtitle.trim() : "";
  const task = typeof value.task === "string" ? value.task.trim() : "";

  if (!title || !subtitle || !task) {
    throw new Error("Chapter fields cannot be empty");
  }

  return { title, subtitle, task };
};

const normalizeChapters = (payload: unknown): Chapter[] => {
  if (!isRecord(payload) || !Array.isArray(payload.chapters)) {
    throw new Error("Invalid chapters payload");
  }

  if (
    payload.chapters.length < MIN_CHAPTER_COUNT ||
    payload.chapters.length > MAX_CHAPTER_COUNT
  ) {
    throw new Error(
      `Expected ${MIN_CHAPTER_COUNT}-${MAX_CHAPTER_COUNT} chapters`,
    );
  }

  return payload.chapters.map(normalizeChapter);
};

const upsertChapterStatus = async (
  db: typeof supabase,
  soulerId: string,
  status: "pending" | "processing" | "complete" | "failed",
  errorMessage: string | null,
) => {
  const { error } = await db
    .from("souler_status")
    .upsert(
      {
        souler_id: soulerId,
        chapters_status: status,
        chapters_error: errorMessage,
      },
      { onConflict: "souler_id" },
    );

  if (error) {
    throw new Error(`Failed to update chapters status: ${error.message}`);
  }
};

Deno.serve(async (req) => {
  if (req.method === "GET") {
    return jsonResponse({ ok: true, service: "souler-chapters-webhook" });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let soulerId = "";

  try {
    const payload = await req.json();
    const resolvedSoulerId = extractSoulerId(payload);
    if (!resolvedSoulerId) {
      return jsonResponse({ error: "Missing souler id in payload" }, 400);
    }
    soulerId = resolvedSoulerId;

    const { data: souler, error: soulerError } = await supabase
      .from("soulers")
      .select("id, name, lang")
      .eq("id", soulerId)
      .maybeSingle();

    if (soulerError) {
      throw new Error(`Failed to load souler: ${soulerError.message}`);
    }

    if (!souler) {
      return jsonResponse({ error: "Souler not found", soulerId }, 404);
    }

    await upsertChapterStatus(supabase, soulerId, "processing", null);

    const lang = typeof souler.lang === "string" ? souler.lang.trim().toLowerCase() : "en";
    const name = typeof souler.name === "string" ? souler.name.trim() : "";
    if (!name) {
      throw new Error("Souler name is empty");
    }

    const raw = await completeJson(buildChapterMessages(name, lang));
    const chapters = normalizeChapters(raw);

    const rows = chapters.map((chapter, index) => ({
      souler_id: soulerId,
      seq: index + 1,
      title: chapter.title,
      subtitle: chapter.subtitle,
      task: chapter.task,
    }));

    const { error: upsertError } = await supabase
      .from("chapters")
      .upsert(rows, { onConflict: "souler_id,seq" });

    if (upsertError) {
      throw new Error(`Failed to upsert chapters: ${upsertError.message}`);
    }

    await upsertChapterStatus(supabase, soulerId, "complete", null);

    return jsonResponse({
      ok: true,
      soulerId,
      status: "complete",
      chapters: rows.length,
    });
  } catch (error) {
    const detail = truncateError(error);
    console.error(
      JSON.stringify({
        source: "souler-chapters-webhook",
        level: "error",
        soulerId,
        message: detail,
      }),
    );

    if (soulerId) {
      try {
        await upsertChapterStatus(supabase, soulerId, "failed", detail);
      } catch (statusError) {
        console.error(
          JSON.stringify({
            source: "souler-chapters-webhook",
            level: "error",
            soulerId,
            message: "Failed to persist failed status",
            detail: truncateError(statusError),
          }),
        );
      }
    }

    return jsonResponse({ error: "Unhandled webhook error", detail }, 500);
  }
});
