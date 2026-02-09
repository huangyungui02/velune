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
        name_en: z.string().optional(),
      }),
    );
    const modelResponse = await model_with_schema.invoke(
      [
        new SystemMessage(
          `对于用户提供的人物和语境片段，给出人物对应的完整中文名(name)，和英文名(name_en)。如果人物没有英文名，则不返回name_en。以json格式返回。`,
        ),
        new HumanMessage(`人物: ${souler} 语境片段: ${content}`),
      ] as unknown as Parameters<typeof model_with_schema.invoke>[0],
    );
    return modelResponse;
  },
);
