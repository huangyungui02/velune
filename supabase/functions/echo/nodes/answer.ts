import { task } from "@langchain/langgraph";
import { modelS } from "../model.ts";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { type Lang } from "../lang.ts";

const answerPrompt: Record<Lang, (prompt: string) => string> = {
  en: (prompt) => `# Role
${prompt}

# Task
Respond to the user's soul fragment in this persona.

# Output
Return only the response content.`,
  zh: (prompt) => `# 角色
${prompt}

# 任务
以此角色身份回应用户的灵魂碎片。

# 输出
仅返回回复内容。`,
};

export const soulerAnswer = task(
  { name: "souler_answer" },
  async (content: string, prompt: string, lang: Lang) => {
    const modelResponse = await modelS.invoke(
      [
        new SystemMessage(answerPrompt[lang](prompt)),
        new HumanMessage(content),
      ] as unknown as Parameters<typeof modelS.invoke>[0],
    );
    return modelResponse.content as string;
  },
);
