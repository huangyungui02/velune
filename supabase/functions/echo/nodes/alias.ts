import { task } from "@langchain/langgraph";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { modelS } from "../model.ts";
import { type Lang } from "../lang.ts";
import { z } from "zod";

const aliasPrompt: Record<Lang, string> = {
  en: `You are an expert in entity resolution and name normalization. Generate a comprehensive list of practical aliases for a given person's name to improve search and matching accuracy.
Rules:
1. Canonical Full Name: Include the complete official name (e.g., "Einstein" -> "Albert Einstein").
2. Pseudonyms & Stage Names: Include known pen names, stage names, or widely recognized monikers (e.g., "Mark Twain" -> "Samuel Langhorne Clemens").
3. Titles & Honorifics: Include forms with commonly associated titles if they are widely used for identification (e.g., "Gandhi" -> "Mahatma Gandhi").
4. Variant Spellings & Transliterations: Include common alternative spellings or anglicized forms (e.g., "Dostoevsky" -> "Dostoyevsky").
5. Diminutives & Nicknames: Include widely accepted short forms (e.g., "Bill Clinton" -> "William Jefferson Clinton").
6. Language: All aliases must be in English.
7. Output: Return ONLY a JSON object with an "aliases" array containing unique, concise, and realistic string values. Do not include explanations.`,
  zh: `你是实体解析和名称标准化的专家。请为给定的人物名称生成全面且实用的别名列表，以提高搜索和匹配的准确性。
规则：
1. 完整姓名：包含官方的完整姓名（例如："爱因斯坦" -> "阿尔伯特·爱因斯坦"）。
2. 笔名与艺名：包含众所周知的笔名、艺名或化名（例如："鲁迅" -> "周树人"）。
3. 字号与尊称：对于历史人物，包含其字、号、谥号或广泛使用的尊称（例如："苏轼" -> "苏东坡"、"苏子瞻"；"甘地" -> "圣雄甘地"）。
4. 异译与拼写变体：包含常见的不同音译或写法（例如："笛卡尔" -> "笛卡儿"、"勒内·笛卡尔"）。
5. 简称与昵称：包含被广泛接受的缩写或简称。
6. 语言：所有别名必须使用中文。
7. 输出：仅返回包含 "aliases" 字符串数组的 JSON 对象。别名应简洁、真实、去重。不要包含任何解释。`,
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
