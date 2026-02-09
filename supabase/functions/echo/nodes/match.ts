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
          `根据用户写下的日记，寻找最能与用户产生共鸣的哲学家、诗人、作家、艺术家、历史人物、宗教人物、神话人物、文学人物、艺术家、心理学家、社会学家、企业家、科学家或其他知名人物。一共返回${num}组数据(data)，每组包含人物(souler)，和一句最能与用户内容共振的片段(content)。以json格式返回。`,
        ),
        new HumanMessage(content),
      ] as unknown as Parameters<typeof model_with_schema.invoke>[0],
    );
    return modelResponse.data;
  },
);
