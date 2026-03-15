from __future__ import annotations

import json
from typing import Any

from openai import AsyncOpenAI

from app.config import get_settings

settings = get_settings()
_client = AsyncOpenAI(
    api_key=settings.DASHSCOPE_API_KEY,
    base_url=settings.DASHSCOPE_BASE_URL,
)


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
    temperature: float,
) -> str:
    completion = await _client.chat.completions.create(
        model=settings.LLM_MODEL,
        messages=messages,
        temperature=temperature,
    )
    content = completion.choices[0].message.content
    return _normalize_content(content).strip()


async def complete_json(
    messages: list[dict[str, str]],
    *,
    schema_name: str,
    schema: dict[str, Any],
    temperature: float,
) -> Any:
    completion = await _client.chat.completions.create(
        model=settings.LLM_MODEL,
        messages=messages,
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
    content = _normalize_content(completion.choices[0].message.content).strip()
    if not content:
        raise ValueError("Model returned empty JSON content")
    return json.loads(content)


async def stream_text(
    messages: list[dict[str, str]],
    *,
    temperature: float,
):
    stream = await _client.chat.completions.create(
        model=settings.LLM_MODEL,
        messages=messages,
        temperature=temperature,
        stream=True,
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
