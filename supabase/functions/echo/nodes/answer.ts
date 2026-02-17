import { task } from "@langchain/langgraph";
import { modelS } from "../model.ts";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { answerPrompt, type Lang } from "../prompts.ts";

export const soulerAnswer = task(
  { name: "souler_answer" },
  async (content: string, prompt: string, lang: Lang) => {
    const modelResponse = await modelS.invoke(
      [
        new SystemMessage(answerPrompt[lang](prompt)),
        new HumanMessage(content),
      ] as unknown as Parameters<typeof modelS.invoke>[0],
    );
    return modelResponse.content as string;
  },
);
