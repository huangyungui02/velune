import OpenAI from "@openai/openai";

const DEFAULT_DASHSCOPE_BASE_URL = "https://dashscope.aliyuncs.com/compatible-mode/v1";
const DEFAULT_QWEN_MODEL = "qwen3.5-plus";

const requireDashscopeApiKey = (): string => {
  const value = Deno.env.get("DASHSCOPE_API_KEY")?.trim();
  if (!value) {
    throw new Error("Missing DASHSCOPE_API_KEY");
  }
  return value;
};

export const openai = new OpenAI({
  apiKey: requireDashscopeApiKey(),
  baseURL: Deno.env.get("DASHSCOPE_BASE_URL")?.trim() || DEFAULT_DASHSCOPE_BASE_URL,
});

export const getQwenModel = (): string => {
  return Deno.env.get("QWEN_MODEL")?.trim() || DEFAULT_QWEN_MODEL;
};

const isQwenModel = (model: string): boolean => {
  return model.trim().toLowerCase().includes("qwen");
};

export const applyQwenNoThinking = <T extends Record<string, unknown>>(
  model: string,
  requestBody: T,
): T => {
  if (isQwenModel(model)) {
    // DashScope OpenAI-compatible API expects enable_thinking as a top-level
    // parameter in Node/Deno SDKs.
    Object.assign(requestBody, { enable_thinking: false });
  }
  return requestBody;
};
