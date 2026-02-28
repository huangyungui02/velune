import { task } from "@langchain/langgraph";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { modelS } from "../model.ts";
import { type Lang, parsePrompt } from "../prompts.ts";
import { z } from "zod";

export const parseSouler = task(
  { name: "parse" },
  async (souler: string, content: string, lang: Lang) => {
    const model_with_schema = modelS.withStructuredOutput(
      z.object({
        name: z.string(),
      }),
    );
    const modelResponse = await model_with_schema.invoke(
      [
        new SystemMessage(parsePrompt[lang]),
        new HumanMessage(`Person: ${souler}\nContext: ${content}`),
      ] as unknown as Parameters<typeof model_with_schema.invoke>[0],
    );
    return modelResponse;
  },
);

export const fetchWikipediaCanonicalName = task(
  { name: "fetch_wikipedia_canonical_name" },
  async (inputName: string, lang: Lang) => {
    const query = inputName.trim();
    if (!query) {
      return { name: inputName, wikiId: null as number | null };
    }

    const endpoint = `https://${lang}.wikipedia.org/w/api.php?` +
      new URLSearchParams({
        action: "query",
        format: "json",
        list: "search",
        srsearch: query,
        srlimit: "1",
        utf8: "1",
        origin: "*",
      }).toString();

    try {
      const response = await fetch(endpoint);
      if (!response.ok) {
        return { name: inputName, wikiId: null as number | null };
      }
      const payload = await response.json() as {
        query?: { search?: Array<{ title?: string; pageid?: number }> };
      };
      const first = payload.query?.search?.[0];
      const title = first?.title?.trim();
      return {
        name: title && title.length > 0 ? title : inputName,
        wikiId: typeof first?.pageid === "number" ? first.pageid : null,
      };
    } catch {
      return { name: inputName, wikiId: null as number | null };
    }
  },
);
