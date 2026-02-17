export type Lang = "zh" | "en";

/**
 * Detect the primary language of the given text.
 * Returns "zh" if Chinese characters exceed 10% of total length, otherwise "en".
 */
export function detectLang(text: string): Lang {
  const cjk = text.match(/[\u4e00-\u9fff]/g);
  return (cjk?.length ?? 0) / text.length > 0.1 ? "zh" : "en";
}

// ── Bilingual prompts ──────────────────────────────────────────────

export const matchPrompt: Record<Lang, (num: number) => string> = {
  en: (num) =>
    `Based on the user's journal entry, find people who would resonate deeply with the user (for example philosophers, poets, writers, artists, historical figures, religious figures, mythological or literary figures, psychologists, sociologists, entrepreneurs, scientists, or other notable people). Return exactly ${num} items in JSON with shape {"data":[{"souler":"...","content":"..."}]}. "souler" is the person's name and "content" is one short quote-like line that best resonates with the user entry.`,
  zh: (num) =>
    `根据用户的日记内容，找到能与用户产生深度共鸣的人物（如哲学家、诗人、作家、艺术家、历史人物、宗教人物、神话或文学角色、心理学家、社会学家、企业家、科学家等杰出人物）。返回恰好 ${num} 条结果，JSON 格式为 {"data":[{"souler":"...","content":"..."}]}。"souler" 为人物姓名，"content" 为一句与用户日记最为共鸣的短语。`,
};

export const parsePrompt: Record<Lang, string> = {
  en: `Given a candidate person and contextual excerpt, return the person's canonical full English name in JSON as {"name": "..."}.`,
  zh: `给定一个候选人物和上下文片段，返回该人物的中文全名，JSON 格式为 {"name": "..."}。`,
};

export const profilePrompt: Record<Lang, string> = {
  en: `Write a profile for the given soul.`,
  zh: `为给定灵魂写一段个人简介。`,
};

export const rolePrompt: Record<Lang, string> = {
  en: `You generate role prompts. For the given person, write a concise character prompt for an LLM to simulate that person. The prompt must start with 'You are'.`,
  zh: `你是角色提示词生成器。为给定人物编写一段简洁的角色提示词，供大语言模型模拟该人物使用。提示词必须以"你是"开头。`,
};

export const answerPrompt: Record<Lang, (prompt: string) => string> = {
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
