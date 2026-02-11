import { task } from "@langchain/langgraph";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { modelL } from "../model.ts";
import { z } from "zod";

export const matchSoulers = task(
  { name: "match_soulers" },
  async (content: string, num: number) => {
    const model_with_schema = modelL.withStructuredOutput(
      z.object({
        data: z
          .array(
            z.object({
              souler: z.string(),
              content: z.string(),
            }),
          )
          .length(num),
      }),
    );
    const modelResponse = await model_with_schema.invoke(
      [
        new SystemMessage(
          `Based on the user's journal entry, find people who would resonate deeply with the user (for example philosophers, poets, writers, artists, historical figures, religious figures, mythological or literary figures, psychologists, sociologists, entrepreneurs, scientists, or other notable people). Return exactly ${num} items in JSON with shape {"data":[{"souler":"...","content":"..."}]}. "souler" is the person's name and "content" is one short quote-like line that best resonates with the user entry. Output must be English only.`,
        ),
        new HumanMessage(content),
      ] as unknown as Parameters<typeof model_with_schema.invoke>[0],
    );
    return modelResponse.data;
  },
);
