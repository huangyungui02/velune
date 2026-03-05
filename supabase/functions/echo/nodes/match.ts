import { task } from "@langchain/langgraph";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { modelL } from "../model.ts";
import { type Lang } from "../lang.ts";
import { z } from "zod";

const matchPrompt: Record<Lang, (num: number) => string> = {
  en: (num) =>
    `Based on the user's journal entry, find people who would resonate deeply with the user (for example philosophers, poets, writers, artists, historical figures, religious figures, mythological or literary figures, psychologists, sociologists, entrepreneurs, scientists, or other notable people). Return exactly ${num} items in JSON with shape {"data":[{"souler":"...","content":"..."}]}. "souler" is the person's name and "content" is one short quote-like line that best resonates with the user entry. All "souler" values must be unique (no duplicate names). The entire output must be in English only: both "souler" and "content" must be English.`,
  zh: (num) =>
    `根据用户的日记内容，找到能与用户产生深度共鸣的人物（如哲学家、诗人、作家、艺术家、历史人物、宗教人物、神话或文学角色、心理学家、社会学家、企业家、科学家等杰出人物）。返回恰好 ${num} 条结果，JSON 格式为 {"data":[{"souler":"...","content":"..."}]}。"souler" 为人物姓名，"content" 为一句与用户日记最为共鸣的短语。所有 "souler" 必须唯一（人物名不可重复）。整个返回结果必须仅使用中文：包括 "souler" 和 "content"。`,
};

export const matchSoulers = task(
  { name: "match_soulers" },
  async (content: string, num: number, lang: Lang) => {
    const model_with_schema = modelL.withStructuredOutput(
      z.object({
        data: z
          .array(
            z.object({
              souler: z.string(),
              content: z.string(),
            }),
          )
          .length(num),
      }),
    );
    const modelResponse = await model_with_schema.invoke(
      [
        new SystemMessage(matchPrompt[lang](num)),
        new HumanMessage(content),
      ] as unknown as Parameters<typeof model_with_schema.invoke>[0],
    );
    return modelResponse.data;
  },
);
