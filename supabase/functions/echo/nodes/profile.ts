import { task } from "@langchain/langgraph";
import { modelS } from "../model.ts";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";

export const soulerProfile = task(
  { name: "souler_profile" },
  async (souler: string) => {
    const modelResponse = await modelS.invoke(
      [
        new SystemMessage(
          "对于用户输入的人物，做人物的主要介绍，用于资料页显示，以Markdown格式返回。请勿给出除人物介绍之外的其他内容",
        ),
        new HumanMessage(souler),
      ] as unknown as Parameters<typeof modelS.invoke>[0],
    );
    return modelResponse.content as string;
  },
);
