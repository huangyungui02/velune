from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator, Callable
from dataclasses import dataclass
from typing import Awaitable, TypeVar, cast

from app.chat.chapters.reply import (
    CHAPTER_JSON_OPEN_MARKER,
    build_chapter_system_prompt,
)
from app.chat.preferences import ReplyLength, apply_reply_length_prompt
from app.config import get_settings
from app.shared import Lang, sanitize_title
from app.llm import complete_text
from app.repositories import ChapterContext, MessageRow, SessionContext

settings = get_settings()

CHAT_MODEL = "qwen3.5-flash"

T = TypeVar("T")


@dataclass(frozen=True)
class PreparedChat:
    user_id: str
    session: SessionContext
    lang: Lang
    content: str
    is_new_session: bool
    should_generate_title: bool
    prompt_messages: list[dict[str, str]]


@dataclass
class ChapterStreamState:
    raw_chunks: list[str]
    output_chunks: list[str]
    pending: str
    phase: str


def build_system_prompt(
    name: str,
    lang: Lang,
    chapter: ChapterContext | None = None,
    reply_length: ReplyLength = "standard",
) -> str:
    if chapter:
        return apply_reply_length_prompt(
            build_chapter_system_prompt(name, chapter, lang),
            lang,
            reply_length,
        )

    template: dict[Lang, str] = {
        "zh": "请以{name}的思想和风格与用户进行深度对话",
        "en": "Please have a deep conversation with the user in the thought and style of {name}.",
    }
    return apply_reply_length_prompt(template[lang].format(name=name), lang, reply_length)


def consume_chapter_stream_delta(
    state: ChapterStreamState,
    delta: str,
) -> str:
    state.raw_chunks.append(delta)
    state.pending += delta
    visible_parts: list[str] = []

    while state.pending:
        pending_lower = state.pending.lower()

        if state.phase == "done":
            break

        if state.phase == "streaming_content":
            marker_lower = CHAPTER_JSON_OPEN_MARKER.lower()
            options_open_index = pending_lower.find(marker_lower)
            if options_open_index >= 0:
                visible = state.pending[:options_open_index]
                if visible:
                    state.output_chunks.append(visible)
                    visible_parts.append(visible)
                state.pending = state.pending[options_open_index:]
                state.phase = "done"
                break

            hold = len(marker_lower) - 1
            if len(state.pending) <= hold:
                break

            visible = state.pending[:-hold]
            state.pending = state.pending[-hold:]
            if visible:
                state.output_chunks.append(visible)
                visible_parts.append(visible)
            break

        raise ValueError(f"Unknown chapter stream phase: {state.phase}")

    return "".join(visible_parts)


async def generate_session_title(
    user_content: str,
    reply_content: str,
    lang: Lang,
    *,
    model: str,
) -> str:
    system_prompt = (
        "根据用户消息和助手回复生成简洁聊天标题。限制 12 个字以内，不要标点，不要引号，只返回标题文本。"
        if lang == "zh"
        else "Create a concise chat title based on the user message and assistant reply. "
        "Keep it under 8 words, no punctuation, no quotes, and return only title text."
    )
    raw = await complete_text(
        [
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": f"User:\n{user_content}\n\nAssistant:\n{reply_content}",
            },
        ],
        model=model,
        temperature=settings.MODEL_S_TEMPERATURE,
    )
    return sanitize_title(raw, lang)


async def run_blocking(
    label: str,
    func: Callable[..., T],
    *args: object,
    timeout: float | None = None,
) -> T:
    try:
        return await asyncio.wait_for(
            asyncio.to_thread(func, *args),
            timeout=timeout or settings.REPO_TIMEOUT_SECONDS,
        )
    except asyncio.TimeoutError as error:
        raise TimeoutError(f"{label} timed out") from error


async def stream_with_timeout(
    chunks: AsyncIterator[str],
    *,
    first_chunk_timeout: float,
    idle_timeout: float,
) -> AsyncIterator[str]:
    iterator = chunks.__aiter__()
    next_timeout = first_chunk_timeout
    try:
        while True:
            try:
                chunk = await asyncio.wait_for(iterator.__anext__(), timeout=next_timeout)
            except StopAsyncIteration:
                return
            except asyncio.TimeoutError as error:
                raise TimeoutError("Model response timed out") from error

            next_timeout = idle_timeout
            yield chunk
    finally:
        aclose = getattr(iterator, "aclose", None)
        if callable(aclose):
            await cast(Callable[[], Awaitable[None]], aclose)()


def build_prompt_messages(
    session: SessionContext,
    history: list[MessageRow],
    content: str,
    lang: Lang,
    reply_length: ReplyLength = "standard",
) -> list[dict[str, str]]:
    prompt_messages: list[dict[str, str]] = [
        {
            "role": "system",
            "content": build_system_prompt(
                session["souler"]["name"],
                lang,
                session.get("chapter"),
                reply_length,
            ),
        }
    ]

    for item in history:
        prompt_messages.append(
            {
                "role": "assistant" if item["role"] == "assistant" else "user",
                "content": str(item["content"]),
            }
        )

    prompt_messages.append({"role": "user", "content": content})
    return prompt_messages


SESSION_TITLE_PROMPT: dict[Lang, str] = {
    "en": "Create a concise chat title from the user's glimmer and souler echo. Keep it under 8 words, no punctuation, no quotes, and return only the title text. Title must be in English only.",
    "zh": "根据用户 glimmer 和 souler echo 生成一个简洁会话标题。限制 8 个字以内，不要标点，不要引号，只返回标题文本。标题必须只使用中文。",
}


async def session_title(glimmer: str, echo: str, lang: Lang, *, model: str) -> str:
    raw = await complete_text(
        [
            {"role": "system", "content": SESSION_TITLE_PROMPT[lang]},
            {"role": "user", "content": f"Glimmer:\n{glimmer}\n\nEcho:\n{echo}"},
        ],
        model=model,
        temperature=settings.MODEL_S_TEMPERATURE,
    )
    return sanitize_title(raw, lang)
