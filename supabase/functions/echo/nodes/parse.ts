import { task } from "@langchain/langgraph";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { modelS } from "../model.ts";
import { z } from "zod";

export const parseSouler = task(
  { name: "parse" },
  async (souler: string, content: string) => {
    const model_with_schema = modelS.withStructuredOutput(
      z.object({
        name: z.string(),
      }),
    );
    const modelResponse = await model_with_schema.invoke(
      [
        new SystemMessage(
          "Given a candidate person and contextual excerpt, return the person's canonical full English name in JSON as {\"name\": \"...\"}. Return only JSON. Output must be English only.",
        ),
        new HumanMessage(`Person: ${souler}\nContext: ${content}`),
      ] as unknown as Parameters<typeof model_with_schema.invoke>[0],
    );
    return modelResponse;
  },
);
