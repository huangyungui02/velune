import { task } from "@langchain/langgraph";
import { modelS } from "../model.ts";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";

const answerPrompt = (prompt: string) => `
# Role
${prompt}

# Task
Respond to the user's soul fragment in this persona.

# Output  
Return only the response content.
Output must be English only.
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
