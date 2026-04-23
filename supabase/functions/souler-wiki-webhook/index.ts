import { supabase } from "../_shared/supabase.ts";
import {
  extractSoulerId,
  isRecord,
  jsonResponse,
  truncateError,
} from "../_shared/webhook.ts";

const WIKIPEDIA_SEARCH_PATH = "/w/api.php";
const WIKIPEDIA_API_PARAMS: Record<string, string> = {
  action: "query",
  format: "json",
  generator: "search",
  gsrlimit: "1",
  prop: "pageprops",
};

const buildWikiSearchUrl = (name: string, lang: string): string => {
  const host = lang === "zh" ? "https://zh.wikipedia.org" : "https://en.wikipedia.org";
  const url = new URL(`${host}${WIKIPEDIA_SEARCH_PATH}`);
  for (const [key, value] of Object.entries(WIKIPEDIA_API_PARAMS)) {
    url.searchParams.set(key, value);
  }
  url.searchParams.set("gsrsearch", name);
  return url.toString();
};

const extractWikibaseItem = (payload: unknown): string | null => {
  if (!isRecord(payload) || !isRecord(payload.query) || !isRecord(payload.query.pages)) {
    return null;
  }

  for (const page of Object.values(payload.query.pages)) {
    if (!isRecord(page) || !isRecord(page.pageprops)) {
      continue;
    }
    const value = page.pageprops.wikibase_item;
    if (typeof value === "string") {
      const normalized = value.trim().toUpperCase();
      if (normalized.startsWith("Q") && normalized.length > 1) {
        return normalized;
      }
    }
  }

  return null;
};

const searchWikiId = async (name: string, lang: string): Promise<string | null> => {
  const url = buildWikiSearchUrl(name, lang);
  const response = await fetch(url, {
    method: "GET",
    headers: {
      "User-Agent": "VeluneSoulerWikiWebhook/1.0",
      "Accept": "application/json",
    },
    signal: AbortSignal.timeout(8_000),
  });

  if (!response.ok) {
    throw new Error(`Wikipedia request failed with status ${response.status}`);
  }

  const payload = await response.json();
  return extractWikibaseItem(payload);
};

Deno.serve(async (req) => {
  if (req.method === "GET") {
    return jsonResponse({ ok: true, service: "souler-wiki-webhook" });
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
      .select("id, name, canonical_name, lang, wiki_id")
      .eq("id", soulerId)
      .maybeSingle();

    if (soulerError) {
      throw new Error(`Failed to load souler: ${soulerError.message}`);
    }
    if (!souler) {
      return jsonResponse({ error: "Souler not found", soulerId }, 404);
    }

    const existingWikiId = typeof souler.wiki_id === "string" ? souler.wiki_id.trim() : "";
    if (existingWikiId) {
      return jsonResponse({
        ok: true,
        soulerId,
        skipped: true,
        reason: "wiki_id_exists",
        wikiId: existingWikiId,
      });
    }

    const canonicalName = typeof souler.canonical_name === "string"
      ? souler.canonical_name.trim()
      : "";
    const fallbackName = typeof souler.name === "string" ? souler.name.trim() : "";
    const queryName = canonicalName || fallbackName;
    if (!queryName) {
      throw new Error("Souler canonical_name and name are both empty");
    }

    const rawLang = typeof souler.lang === "string" ? souler.lang.trim().toLowerCase() : "en";
    const wikiLang = rawLang === "zh" ? "zh" : "en";
    const wikiId = await searchWikiId(queryName, wikiLang);
    if (!wikiId) {
      return jsonResponse({
        ok: true,
        soulerId,
        skipped: true,
        reason: "wikibase_item_not_found",
      });
    }

    const { error: updateError } = await supabase
      .from("soulers")
      .update({ wiki_id: wikiId })
      .eq("id", soulerId);
    if (updateError) {
      throw new Error(`Failed to update souler wiki_id: ${updateError.message}`);
    }

    return jsonResponse({
      ok: true,
      soulerId,
      wikiId,
      status: "complete",
    });
  } catch (error) {
    const detail = truncateError(error);
    console.error(
      JSON.stringify({
        source: "souler-wiki-webhook",
        level: "error",
        soulerId,
        message: detail,
      }),
    );
    return jsonResponse({ error: "Unhandled webhook error", detail }, 500);
  }
});
