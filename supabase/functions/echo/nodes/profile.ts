import { task } from "@langchain/langgraph";
import { modelS } from "../model.ts";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";

export const soulerProfile = task(
  { name: "souler_profile" },
  async (souler: string) => {
    const modelResponse = await modelS.invoke(
      [
        new SystemMessage(
          "Write a concise profile for the given person for an app detail page. Return Markdown only, focused on who they are, key ideas, and why they matter. Output must be English only.",
        ),
        new HumanMessage(souler),
      ] as unknown as Parameters<typeof modelS.invoke>[0],
    );
    return modelResponse.content as string;
  },
);
