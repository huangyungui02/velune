import { ChatOpenAI } from "@langchain/openai";

const dashscope_api_key = Deno.env.get("DASHSCOPE_API_KEY")!;
const dashscope_api_base_url =
  "https://dashscope.aliyuncs.com/compatible-mode/v1";
const model_name = "qwen-plus";

//small random model
export const modelS = new ChatOpenAI({
  model: model_name,
  apiKey: dashscope_api_key,
  temperature: 0.25,
  configuration: {
    baseURL: dashscope_api_base_url,
  },
});

//medium random model
export const modelM = new ChatOpenAI({
  model: model_name,
  apiKey: dashscope_api_key,
  temperature: 0.5,
  configuration: {
    baseURL: dashscope_api_base_url,
  },
});

//large random model
export const modelL = new ChatOpenAI({
  model: model_name,
  apiKey: dashscope_api_key,
  temperature: 0.75,
  configuration: {
    baseURL: dashscope_api_base_url,
  },
});
