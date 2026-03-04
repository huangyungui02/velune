import { task } from "@langchain/langgraph";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { modelS } from "../model.ts";
import { sessionTitlePrompt, type Lang } from "../prompts.ts";

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
