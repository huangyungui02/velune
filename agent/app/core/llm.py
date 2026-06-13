from __future__ import annotations

from collections.abc import AsyncIterator
from typing import Any, TypeVar, cast

from langchain_qwq import ChatQwen
from pydantic import BaseModel

from app.core.config import get_settings

DEFAULT_MODEL = "qwen3.5-flash"
PREMIUM_MODEL = "qwen3.5-plus"
StructuredOutputT = TypeVar("StructuredOutputT", bound=BaseModel)


def model_for_premium(is_premium: bool) -> str:
    return PREMIUM_MODEL if is_premium else DEFAULT_MODEL


def create_chat_model(model: str, **model_kwargs: Any) -> ChatQwen:
    settings = get_settings()

    return ChatQwen(
        api_key=settings.DASHSCOPE_API_KEY,
        base_url=settings.DASHSCOPE_BASE_URL,
        model=model,
        enable_thinking=False,
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
    structured_model = create_chat_model(model=model, temperature=temperature).with_structured_output(schema)
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
