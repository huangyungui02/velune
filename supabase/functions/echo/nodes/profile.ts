import { task } from "@langchain/langgraph";
import { modelS } from "../model.ts";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { type Lang } from "../lang.ts";

const profilePrompt: Record<Lang, string> = {
  en: `Write an introduction for the given souler.`,
  zh: `为给定灵魂写一段人物简介。`,
};

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
