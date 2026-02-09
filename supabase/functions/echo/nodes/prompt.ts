import { task } from "@langchain/langgraph";
import { modelS } from "../model.ts";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";

export const soulerPrompt = task(
  { name: "souler_prompt" },
  async (souler: string) => {
    const modelResponse = await modelS.invoke(
      [
        new SystemMessage(
          '你是提示词生成器，对于用户输入的人物，给出对应提示词，用做大模型的人物模拟，以"你是"开头',
        ),
        new HumanMessage(souler),
      ] as unknown as Parameters<typeof modelS.invoke>[0],
    );
    return modelResponse.content as string;
  },
);
