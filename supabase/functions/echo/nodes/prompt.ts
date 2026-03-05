import { task } from "@langchain/langgraph";
import { modelS } from "../model.ts";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { type Lang } from "../lang.ts";

const rolePrompt: Record<Lang, string> = {
  en: `You generate role prompts. For the given person, write a concise character prompt for an LLM to simulate that person. The prompt must start with 'You are'.`,
  zh: `你是角色提示词生成器。为给定人物编写一段简洁的角色提示词，供大语言模型模拟该人物使用。提示词必须以"你是"开头。`,
};

export const soulerPrompt = task(
  { name: "souler_prompt" },
  async (souler: string, lang: Lang) => {
    const modelResponse = await modelS.invoke(
      [
        new SystemMessage(rolePrompt[lang]),
        new HumanMessage(souler),
      ] as unknown as Parameters<typeof modelS.invoke>[0],
    );
    return modelResponse.content as string;
  },
);
