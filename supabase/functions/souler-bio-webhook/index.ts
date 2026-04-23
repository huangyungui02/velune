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
  BIO_SYSTEM_PROMPT_EN,
  BIO_SYSTEM_PROMPT_ZH,
} from "./prompts.ts";

type ChatMessage = { role: "system" | "user"; content: string };

type BioKeyword = {
  word: string;
  weight: number;
};

type BioPayload = {
  introduction: string;
  keywords: BioKeyword[];
};

const QWEN_MODEL = getQwenModel();
const BIO_TEMPERATURE = 0.25;
const MODEL_TIMEOUT_MS = 60_000;
const KEYWORD_COUNT = 5;

const BIO_SCHEMA: Json = {
  type: "object",
  required: ["introduction", "keywords"],
  properties: {
    introduction: {
      type: "string",
      description: "Person introduction",
    },
    keywords: {
      type: "array",
      description: "Core theme keywords",
      minItems: KEYWORD_COUNT,
      maxItems: KEYWORD_COUNT,
      items: {
        type: "object",
        required: ["word", "weight"],
        properties: {
          word: {
            type: "string",
            description: "Keyword",
          },
          weight: {
            type: "number",
            description: "Keyword weight",
            minimum: 0,
            maximum: 1,
          },
        },
        additionalProperties: false,
      },
    },
  },
  additionalProperties: false,
};

const buildBioMessages = (soulerName: string, lang: string): ChatMessage[] => {
  const prompt = lang === "zh" ? BIO_SYSTEM_PROMPT_ZH : BIO_SYSTEM_PROMPT_EN;
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
    temperature: BIO_TEMPERATURE,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "souler_bio_keywords",
        strict: true,
        schema: BIO_SCHEMA,
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
    throw new Error("Model returned empty bio payload");
  }

  try {
    return JSON.parse(text);
  } catch {
    throw new Error("Model returned non-JSON bio payload");
  }
};

const normalizeKeyword = (value: unknown): BioKeyword => {
  if (!isRecord(value)) {
    throw new Error("Invalid keyword item");
  }

  const word = typeof value.word === "string" ? value.word.trim() : "";
  const weight = typeof value.weight === "number" ? value.weight : NaN;

  if (!word) {
    throw new Error("Keyword word cannot be empty");
  }
  if (!Number.isFinite(weight) || weight < 0 || weight > 1) {
    throw new Error("Keyword weight must be a number between 0 and 1");
  }

  return {
    word,
    weight,
  };
};

const normalizeBioPayload = (payload: unknown): BioPayload => {
  if (!isRecord(payload) || !Array.isArray(payload.keywords)) {
    throw new Error("Invalid bio payload");
  }

  const introduction = typeof payload.introduction === "string"
    ? payload.introduction.trim()
    : "";
  if (!introduction) {
    throw new Error("Introduction cannot be empty");
  }

  const keywords = payload.keywords.map(normalizeKeyword);
  if (keywords.length !== KEYWORD_COUNT) {
    throw new Error(`Expected exactly ${KEYWORD_COUNT} keywords`);
  }

  const uniqueMap = new Map<string, BioKeyword>();
  for (const item of keywords) {
    const key = item.word.toLowerCase();
    if (uniqueMap.has(key)) {
      throw new Error("Keywords must be unique");
    }
    uniqueMap.set(key, item);
  }

  return {
    introduction,
    keywords: Array.from(uniqueMap.values()),
  };
};

const upsertBioStatus = async (
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
        bio_status: status,
        bio_error: errorMessage,
      },
      { onConflict: "souler_id" },
    );

  if (error) {
    throw new Error(`Failed to update bio status: ${error.message}`);
  }
};

const upsertKeywordRelations = async (
  soulerId: string,
  language: string,
  keywords: BioKeyword[],
) => {
  const keywordRows = keywords.map((item) => ({
    word: item.word,
    language,
  }));

  const { data: storedKeywords, error: upsertKeywordsError } = await supabase
    .from("keywords")
    .upsert(keywordRows, { onConflict: "word,language" })
    .select("id, word");

  if (upsertKeywordsError) {
    throw new Error(`Failed to upsert keywords: ${upsertKeywordsError.message}`);
  }
  if (!Array.isArray(storedKeywords) || storedKeywords.length !== keywordRows.length) {
    throw new Error("Keyword upsert returned unexpected result");
  }

  const keywordIdByWord = new Map<string, string>();
  for (const row of storedKeywords) {
    const word = typeof row.word === "string" ? row.word.trim() : "";
    const keywordId = typeof row.id === "string" ? row.id.trim() : "";
    if (!word || !keywordId) {
      continue;
    }
    keywordIdByWord.set(word.toLowerCase(), keywordId);
  }

  const relationRows = keywords.map((item) => {
    const keywordId = keywordIdByWord.get(item.word.toLowerCase());
    if (!keywordId) {
      throw new Error(`Missing keyword id for word: ${item.word}`);
    }

    return {
      souler_id: soulerId,
      keyword_id: keywordId,
      weight: item.weight,
    };
  });

  const { error: deleteRelationsError } = await supabase
    .from("souler_keyword")
    .delete()
    .eq("souler_id", soulerId);
  if (deleteRelationsError) {
    throw new Error(`Failed to clear souler keywords: ${deleteRelationsError.message}`);
  }

  const { error: insertRelationsError } = await supabase
    .from("souler_keyword")
    .insert(relationRows);
  if (insertRelationsError) {
    throw new Error(`Failed to insert souler keywords: ${insertRelationsError.message}`);
  }
};

Deno.serve(async (req) => {
  if (req.method === "GET") {
    return jsonResponse({ ok: true, service: "souler-bio-webhook" });
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
      .select("id, name, canonical_name, lang")
      .eq("id", soulerId)
      .maybeSingle();

    if (soulerError) {
      throw new Error(`Failed to load souler: ${soulerError.message}`);
    }

    if (!souler) {
      return jsonResponse({ error: "Souler not found", soulerId }, 404);
    }

    await upsertBioStatus(supabase, soulerId, "processing", null);

    const lang = typeof souler.lang === "string" ? souler.lang.trim().toLowerCase() : "en";
    const normalizedLang = lang === "zh" ? "zh" : "en";
    const canonicalName = typeof souler.canonical_name === "string"
      ? souler.canonical_name.trim()
      : "";
    const fallbackName = typeof souler.name === "string" ? souler.name.trim() : "";
    const inputName = canonicalName || fallbackName;
    if (!inputName) {
      throw new Error("Souler name is empty");
    }

    const raw = await completeJson(buildBioMessages(inputName, normalizedLang));
    const generated = normalizeBioPayload(raw);

    const { error: updateSoulerError } = await supabase
      .from("soulers")
      .update({ bio: generated.introduction })
      .eq("id", soulerId);
    if (updateSoulerError) {
      throw new Error(`Failed to update souler bio: ${updateSoulerError.message}`);
    }

    await upsertKeywordRelations(soulerId, normalizedLang, generated.keywords);
    await upsertBioStatus(supabase, soulerId, "complete", null);

    return jsonResponse({
      ok: true,
      soulerId,
      status: "complete",
      bioLength: generated.introduction.length,
      keywords: generated.keywords.length,
    });
  } catch (error) {
    const detail = truncateError(error);
    console.error(
      JSON.stringify({
        source: "souler-bio-webhook",
        level: "error",
        soulerId,
        message: detail,
      }),
    );

    if (soulerId) {
      try {
        await upsertBioStatus(supabase, soulerId, "failed", detail);
      } catch (statusError) {
        console.error(
          JSON.stringify({
            source: "souler-bio-webhook",
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
