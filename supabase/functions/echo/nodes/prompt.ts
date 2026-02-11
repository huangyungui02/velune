import { task } from "@langchain/langgraph";
import { modelS } from "../model.ts";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";

export const soulerPrompt = task(
  { name: "souler_prompt" },
  async (souler: string) => {
    const modelResponse = await modelS.invoke(
      [
        new SystemMessage(
          "You generate role prompts. For the given person, write a concise character prompt for an LLM to simulate that person. The prompt must start with 'You are'. Output must be English only.",
        ),
        new HumanMessage(souler),
      ] as unknown as Parameters<typeof modelS.invoke>[0],
    );
    return modelResponse.content as string;
  },
);
