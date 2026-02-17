import { task } from "@langchain/langgraph";
import { modelS } from "../model.ts";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { type Lang, profilePrompt } from "../prompts.ts";

export const soulerProfile = task(
  { name: "souler_profile" },
  async (souler: string, lang: Lang) => {
    const modelResponse = await modelS.invoke(
      [
        new SystemMessage(profilePrompt[lang]),
        new HumanMessage(souler),
      ] as unknown as Parameters<typeof modelS.invoke>[0],
    );
    return modelResponse.content as string;
  },
);
