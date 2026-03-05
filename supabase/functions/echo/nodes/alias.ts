import { task } from "@langchain/langgraph";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { modelS } from "../model.ts";
import { aliasPrompt, type Lang } from "../prompts.ts";
import { z } from "zod";

const normalizeAliases = (name: string, aliases: string[]) => {
  const seen = new Set<string>();
  const results: string[] = [];
  const push = (candidate: string) => {
    const cleaned = candidate.trim();
    if (!cleaned) return;
    const key = cleaned.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    results.push(cleaned);
  };

  // Always preserve original matched name for stable lookups.
  push(name);
  for (const alias of aliases) push(alias);
  return results;
};

export const generateSoulerAliases = task(
  { name: "generate_souler_aliases" },
  async (name: string, lang: Lang) => {
    const cleanedName = name.trim();
    if (!cleanedName) {
      return [name];
    }

    const modelWithSchema = modelS.withStructuredOutput(
      z.object({
        aliases: z.array(z.string()),
      }),
    );
    const modelResponse = await modelWithSchema.invoke(
      [
        new SystemMessage(aliasPrompt[lang]),
        new HumanMessage(`Name: ${cleanedName}`),
      ] as unknown as Parameters<typeof modelWithSchema.invoke>[0],
    );
    return normalizeAliases(cleanedName, modelResponse.aliases);
  },
);
