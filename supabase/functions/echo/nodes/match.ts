import { task } from "@langchain/langgraph";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { modelL } from "../model.ts";
import { type Lang } from "../lang.ts";
import { z } from "zod";

const matchPrompt: Record<Lang, (num: number) => string> = {
  en: (num) =>
    `Analyze the user's journal entry to understand their emotional state, inner thoughts, and struggles. Find exactly ${num} specific figures who can deeply resonate with the user's current state of mind and continue a meaningful conversation about their thoughts. Return JSON with shape {"data":[{"souler":"...","content":"..."}]}. "souler" MUST be the exact name of a specific, well-known person. NEVER use generic terms, roles, or placeholders like "Unknown", "Someone", or "A Friend". "content" must be a profound, empathetic quote or response from their perspective that speaks directly to the user's soul. All "souler" values must be unique. The entire output must be in English.`,
  zh: (num) =>
    `深入分析用户的日记，理解其情感状态、内在想法与挣扎。找到恰好 ${num} 位能够与用户当下心境产生深度共鸣、并能顺着用户的心境继续深入探讨的具体人物。返回 JSON 格式 {"data":[{"souler":"...","content":"..."}]}。"souler" 必须是具体、确切的知名人物姓名。绝不允许使用任何泛指、代词或占位符，如“Unknown”、“未知”、“某人”或“朋友”。"content" 应当是一句深邃、富有同理心的回应，或是该人物的一句名言，能够精准触动用户的灵魂。所有 "souler" 必须唯一。整个返回结果必须仅使用中文。`,
};

export const matchSoulers = task(
  { name: "match_soulers" },
  async (content: string, num: number, lang: Lang) => {
    const model_with_schema = modelL.withStructuredOutput(
      z.object({
        data: z
          .array(
            z.object({
              souler: z
                .string()
                .describe(
                  "Exact name of a specific person. NEVER use 'Unknown' or generic terms.",
                ),
              content: z
                .string()
                .describe(
                  "A profound, empathetic quote or response from their perspective.",
                ),
            }),
          )
          .length(num),
      }),
    );
    const modelResponse = await model_with_schema.invoke([
      new SystemMessage(matchPrompt[lang](num)),
      new HumanMessage(content),
    ] as unknown as Parameters<typeof model_with_schema.invoke>[0]);
    return modelResponse.data;
  },
);
