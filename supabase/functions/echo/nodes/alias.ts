import { task } from "@langchain/langgraph";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { modelS } from "../model.ts";
import { type Lang } from "../lang.ts";
import { z } from "zod";

const aliasPrompt: Record<Lang, string> = {
  en:
    `You normalize person names and generate practical aliases for matching.
Return JSON as {"aliases":["..."]}.
Rules:
1) Include the canonical full name if applicable (e.g. Einstein -> Albert Einstein).
2) Include common transliterations or variant spellings (e.g. Descartes -> Deka'er).
3) Include other widely used aliases or titles.
4) Keep aliases concise, realistic, and useful for name matching.
5) No explanations, only aliases in JSON.
6) Use English only for all aliases.`,
  zh:
    `你需要为人物名称生成可用于匹配的别名。
返回 JSON：{"aliases":["..."]}。
规则：
1) 包含完整姓名（如适用，例如：爱因斯坦 -> 阿尔伯特 爱因斯坦）。
2) 包含常见音译或不同写法（例如：笛卡尔 -> 笛卡儿）。
3) 包含其他广泛使用的别称或称号。
4) 别名应简洁、真实、可用于检索匹配。
5) 不要解释，只返回 JSON 别名数组。
6) 所有别名只能使用中文。`,
};

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
