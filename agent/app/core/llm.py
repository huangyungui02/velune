from __future__ import annotations

from collections.abc import AsyncIterator
from typing import Any

from langchain_openai import ChatOpenAI

from app.core.config import get_settings

DEFAULT_MODEL = "qwen3.5-flash"
NO_THINKING_MODELS = {"qwen3.5-flash"}


def create_chat_model(model: str, **model_kwargs: Any) -> ChatOpenAI:
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


async def complete_text(
    messages: list[dict[str, str]],
    *,
    model: str,
    temperature: float,
) -> str:
    response = await create_chat_model(model=model, temperature=temperature).ainvoke(messages)
    return str(response.content).strip()


async def complete_json(
    messages: list[dict[str, str]],
    *,
    model: str,
    schema_name: str,
    schema: dict[str, Any],
    temperature: float,
) -> dict[str, Any]:
    structured_model = create_chat_model(model=model, temperature=temperature).with_structured_output(
        {"title": schema_name, **schema},
        method="json_schema",
        strict=True,
    )
    response = await structured_model.ainvoke(messages)
    if not isinstance(response, dict):
        raise ValueError("Model returned invalid JSON content")
    return response


async def stream_text(
    messages: list[dict[str, str]],
    *,
    model: str,
    temperature: float,
) -> AsyncIterator[str]:
    async for chunk in create_chat_model(model=model, temperature=temperature).astream(messages):
        if chunk.content:
            yield str(chunk.content)
