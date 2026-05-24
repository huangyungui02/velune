from __future__ import annotations

from langchain_openai import ChatOpenAI

from app.core.config import get_settings

NO_THINKING_MODELS = {"qwen3.5-flash"}


def create_chat_model(model: str, **model_kwargs) -> ChatOpenAI:
    settings = get_settings()
    if not settings.DASHSCOPE_API_KEY:
        raise RuntimeError("DASHSCOPE_API_KEY is required to call DashScope models.")

    if model in NO_THINKING_MODELS:
        extra_body = dict(model_kwargs.pop("extra_body", {}) or {})
        extra_body["enable_thinking"] = False
        model_kwargs["extra_body"] = extra_body

    return ChatOpenAI(
        api_key=settings.DASHSCOPE_API_KEY,
        base_url=settings.DASHSCOPE_BASE_URL,
        model=model,
        **model_kwargs,
    )
