import { task } from "@langchain/langgraph";
import { modelS } from "../model.ts";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";

const answerPrompt = (prompt: string) => `
# Role
${prompt}

# Task
针对用户写下的灵魂碎片，进行回应

# Output  
只需给出回应的内容
`;

export const soulerAnswer = task(
  { name: "souler_answer" },
  async (content: string, prompt: string) => {
    const modelResponse = await modelS.invoke(
      [
        new SystemMessage(answerPrompt(prompt)),
        new HumanMessage(content),
      ] as unknown as Parameters<typeof modelS.invoke>[0],
    );
    return modelResponse.content as string;
  },
);
