from __future__ import annotations

from collections.abc import AsyncIterator
from typing import Any, TypeVar, cast

from langchain_openai import ChatOpenAI
from pydantic import BaseModel

from app.core.config import get_settings

DEFAULT_MODEL = "qwen3.5-flash"
NO_THINKING_MODELS = {"qwen3.5-flash"}
StructuredOutputT = TypeVar("StructuredOutputT", bound=BaseModel)


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


async def complete_structured(
    messages: list[dict[str, str]],
    *,
    model: str,
    schema: type[StructuredOutputT],
    temperature: float,
) -> StructuredOutputT:
    structured_model = create_chat_model(model=model, temperature=temperature).with_structured_output(
        schema,
        method="json_mode",
    )
    response = await structured_model.ainvoke(messages)
    return cast(StructuredOutputT, response)


async def stream_text(
    messages: list[dict[str, str]],
    *,
    model: str,
    temperature: float,
) -> AsyncIterator[str]:
    async for chunk in create_chat_model(model=model, temperature=temperature).astream(messages):
        if chunk.content:
            yield str(chunk.content)
