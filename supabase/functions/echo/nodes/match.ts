import { task } from "@langchain/langgraph";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { modelL } from "../model.ts";
import { type Lang, matchPrompt } from "../prompts.ts";
import { z } from "zod";

export const matchSoulers = task(
  { name: "match_soulers" },
  async (content: string, num: number, lang: Lang) => {
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
        new SystemMessage(matchPrompt[lang](num)),
        new HumanMessage(content),
      ] as unknown as Parameters<typeof model_with_schema.invoke>[0],
    );
    return modelResponse.data;
  },
);
