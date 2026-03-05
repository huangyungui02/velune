import { task } from "@langchain/langgraph";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { modelS } from "../model.ts";
import { type Lang } from "../lang.ts";

const sessionTitlePrompt: Record<Lang, string> = {
  en: `Create a concise chat title from the user's glimmer and souler echo. Keep it under 8 words, no punctuation, no quotes, and return only the title text.`,
  zh: `根据用户 glimmer 和 souler echo 生成一个简洁会话标题。限制 8 个字以内，不要标点，不要引号，只返回标题文本。`,
};

const sanitizeTitle = (raw: string, lang: Lang) => {
  const trimmed = raw.trim().replace(/^["'`]+|["'`]+$/g, "");
  if (!trimmed) {
    return lang === "zh" ? "未命名会话" : "Untitled Session";
  }

  if (lang === "zh") {
    return trimmed.slice(0, 16);
  }

  return trimmed
    .split(/\s+/)
    .slice(0, 8)
    .join(" ");
};

export const sessionTitle = task(
  { name: "session_title" },
  async (glimmer: string, echo: string, lang: Lang) => {
    const response = await modelS.invoke(
      [
        new SystemMessage(sessionTitlePrompt[lang]),
        new HumanMessage(`Glimmer:\n${glimmer}\n\nEcho:\n${echo}`),
      ] as unknown as Parameters<typeof modelS.invoke>[0],
    );
    return sanitizeTitle(String(response.content ?? ""), lang);
  },
);
