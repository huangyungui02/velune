import { task } from "@langchain/langgraph";
import { modelS } from "../model.ts";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { type Lang, rolePrompt } from "../prompts.ts";

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
