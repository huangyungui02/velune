from __future__ import annotations

import json
from typing import Any, cast

from openai import AsyncOpenAI, AsyncStream
from openai.types.chat import ChatCompletion, ChatCompletionChunk

from app.config import get_settings

DEFAULT_MODEL = "qwen3.5-flash"

settings = get_settings()
_client = AsyncOpenAI(
    api_key=settings.DASHSCOPE_API_KEY,
    base_url=settings.DASHSCOPE_BASE_URL,
)


def _build_model_extra_body(model: str) -> dict[str, Any]:
    if model.strip().lower().startswith("qwen"):
        return {"enable_thinking": False}
    return {}


def _build_chat_request(
    messages: list[dict[str, str]],
    *,
    model: str,
    temperature: float,
    **extra: Any,
) -> dict[str, Any]:
    request: dict[str, Any] = {
        "model": model,
        "messages": messages,
        "temperature": temperature,
        **extra,
    }
    extra_body = _build_model_extra_body(model)
    if extra_body:
        request["extra_body"] = extra_body
    return request


def _normalize_content(content: Any) -> str:
    if isinstance(content, str):
        return content

    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, str):
                parts.append(item)
                continue
            if isinstance(item, dict):
                text = item.get("text")
                if isinstance(text, str):
                    parts.append(text)
        return "".join(parts)

    return ""


async def complete_text(
    messages: list[dict[str, str]],
    *,
    model: str,
    temperature: float,
) -> str:
    request = _build_chat_request(
        messages,
        model=model,
        temperature=temperature,
    )
    completion = cast(ChatCompletion, await _client.chat.completions.create(**request))
    content = completion.choices[0].message.content
    return _normalize_content(content).strip()


async def complete_json(
    messages: list[dict[str, str]],
    *,
    model: str,
    schema_name: str,
    schema: dict[str, Any],
    temperature: float,
) -> Any:
    request = _build_chat_request(
        messages,
        model=model,
        temperature=temperature,
        response_format={
            "type": "json_schema",
            "json_schema": {
                "name": schema_name,
                "strict": True,
                "schema": schema,
            },
        },
    )

    completion = cast(ChatCompletion, await _client.chat.completions.create(**request))
    content = _normalize_content(completion.choices[0].message.content).strip()
    if not content:
        raise ValueError("Model returned empty JSON content")
    return json.loads(content)


async def stream_text(
    messages: list[dict[str, str]],
    *,
    model: str,
    temperature: float,
):
    request = _build_chat_request(
        messages,
        model=model,
        temperature=temperature,
        stream=True,
    )
    stream = cast(
        AsyncStream[ChatCompletionChunk],
        await _client.chat.completions.create(**request),
    )
    async for chunk in stream:
        if not chunk.choices:
            continue

        delta = chunk.choices[0].delta.content
        if isinstance(delta, str) and delta:
            yield delta
            continue

        if isinstance(delta, list):
            text = _normalize_content(delta)
            if text:
                yield text
