import { task } from "@langchain/langgraph";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { modelS } from "../model.ts";
import { type Lang, parsePrompt } from "../prompts.ts";
import { z } from "zod";

export const parseSouler = task(
  { name: "parse" },
  async (souler: string, content: string, lang: Lang) => {
    const model_with_schema = modelS.withStructuredOutput(
      z.object({
        name: z.string(),
      }),
    );
    const modelResponse = await model_with_schema.invoke(
      [
        new SystemMessage(parsePrompt[lang]),
        new HumanMessage(`Person: ${souler}\nContext: ${content}`),
      ] as unknown as Parameters<typeof model_with_schema.invoke>[0],
    );
    return modelResponse;
  },
);
