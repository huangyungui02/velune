export type Lang = "zh" | "en";

// ── Bilingual prompts ──────────────────────────────────────────────

export const matchPrompt: Record<Lang, (num: number) => string> = {
  en: (num) =>
    `Based on the user's journal entry, find people who would resonate deeply with the user (for example philosophers, poets, writers, artists, historical figures, religious figures, mythological or literary figures, psychologists, sociologists, entrepreneurs, scientists, or other notable people). Return exactly ${num} items in JSON with shape {"data":[{"souler":"...","content":"..."}]}. "souler" is the person's name and "content" is one short quote-like line that best resonates with the user entry.`,
  zh: (num) =>
    `根据用户的日记内容，找到能与用户产生深度共鸣的人物（如哲学家、诗人、作家、艺术家、历史人物、宗教人物、神话或文学角色、心理学家、社会学家、企业家、科学家等杰出人物）。返回恰好 ${num} 条结果，JSON 格式为 {"data":[{"souler":"...","content":"..."}]}。"souler" 为人物姓名，"content" 为一句与用户日记最为共鸣的短语。`,
};

export const aliasPrompt: Record<Lang, string> = {
  en:
    `You normalize person names and generate practical aliases for matching.
Return JSON as {"aliases":["..."]}.
Rules:
1) Include the canonical full name if applicable (e.g. Einstein -> Albert Einstein).
2) Include common transliterations or variant spellings (e.g. Descartes -> Deka'er).
3) Include other widely used aliases or titles.
4) Keep aliases concise, realistic, and useful for name matching.
5) No explanations, only aliases in JSON.`,
  zh:
    `你需要为人物名称生成可用于匹配的别名。
返回 JSON：{"aliases":["..."]}。
规则：
1) 包含完整姓名（如适用，例如：爱因斯坦 -> 阿尔伯特 爱因斯坦）。
2) 包含常见音译或不同写法（例如：笛卡尔 -> 笛卡儿）。
3) 包含其他广泛使用的别称或称号。
4) 别名应简洁、真实、可用于检索匹配。
5) 不要解释，只返回 JSON 别名数组。`,
};

export const profilePrompt: Record<Lang, string> = {
  en: `Write an introduction for the given souler.`,
  zh: `为给定灵魂写一段人物简介。`,
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

export const sessionTitlePrompt: Record<Lang, string> = {
  en: `Create a concise chat title from the user's glimmer and souler echo. Keep it under 8 words, no punctuation, no quotes, and return only the title text.`,
  zh: `根据用户 glimmer 和 souler echo 生成一个简洁会话标题。限制 8 个字以内，不要标点，不要引号，只返回标题文本。`,
};
