import {
  applyQwenNoThinking,
  openai,
  getQwenModel,
} from "../_shared/openai.ts";
import { supabase } from "../_shared/supabase.ts";
import { extractSoulerId, jsonResponse, truncateError } from "../_shared/webhook.ts";

type ChatMessage = { role: "system" | "user"; content: string };

const QWEN_MODEL = getQwenModel();
const BIO_TEMPERATURE = 0.25;

const PROFILE_PROMPT: Record<string, string> = {
  en: "Write an introduction for the given person.",
  zh: "为给定人物写一段人物简介。",
};

const buildBioMessages = (soulerName: string, lang: string): ChatMessage[] => {
  const prompt = PROFILE_PROMPT[lang] || PROFILE_PROMPT.en;
  return [
    {
      role: "system",
      content: prompt,
    },
    { role: "user", content: soulerName },
  ];
};

const completeText = async (messages: ChatMessage[]): Promise<string> => {
  const requestBody = applyQwenNoThinking(QWEN_MODEL, {
    model: QWEN_MODEL,
    messages,
    temperature: BIO_TEMPERATURE,
  });

  const completion = await openai.chat.completions.create(requestBody as never);
  const content = completion.choices?.[0]?.message?.content;
  const text = typeof content === "string" ? content.trim() : "";
  if (!text) {
    throw new Error("Model returned empty bio");
  }

  return text;
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
      .select("id, name, lang, bio")
      .eq("id", soulerId)
      .maybeSingle();

    if (soulerError) {
      throw new Error(`Failed to load souler: ${soulerError.message}`);
    }

    if (!souler) {
      return jsonResponse({ error: "Souler not found", soulerId }, 404);
    }

    const existingBio = typeof souler.bio === "string" ? souler.bio.trim() : "";
    if (existingBio) {
      await upsertBioStatus(supabase, soulerId, "complete", null);
      return jsonResponse({ ok: true, skipped: true, reason: "bio_exists", soulerId });
    }

    await upsertBioStatus(supabase, soulerId, "processing", null);

    const lang = typeof souler.lang === "string" ? souler.lang.trim().toLowerCase() : "en";
    const name = typeof souler.name === "string" ? souler.name.trim() : "";
    if (!name) {
      throw new Error("Souler name is empty");
    }

    const generatedBio = await completeText(buildBioMessages(name, lang));

    const { error: updateSoulerError } = await supabase
      .from("soulers")
      .update({ bio: generatedBio })
      .eq("id", soulerId);

    if (updateSoulerError) {
      throw new Error(`Failed to update souler bio: ${updateSoulerError.message}`);
    }

    await upsertBioStatus(supabase, soulerId, "complete", null);

    return jsonResponse({
      ok: true,
      soulerId,
      status: "complete",
      bioLength: generatedBio.length,
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
