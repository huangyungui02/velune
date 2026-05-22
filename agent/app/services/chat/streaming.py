from __future__ import annotations

import asyncio
import logging
from collections.abc import AsyncIterator, Awaitable, Callable
from dataclasses import dataclass
from typing import cast

from app.core.config import get_settings
from app.core.llm import DEFAULT_MODEL, stream_text
from app.domain import Session
from app.services.chat.chapters.response import (
    ChapterStreamState,
    consume_chapter_stream_delta,
    parse_chapter_response,
)
from app.services.chat.types import PreparedChat

logger = logging.getLogger(__name__)
settings = get_settings()


@dataclass(frozen=True)
class StreamResult:
    final_content: str
    storage_content: str
    options: list[str]
    tail_delta: str | None


def chapter_stream_state(session: Session) -> ChapterStreamState | None:
    if not session.get("chapter"):
        return None
    return ChapterStreamState(
        raw_chunks=[],
        output_chunks=[],
        pending="",
        phase="streaming_content",
    )


async def iter_model_deltas(prepared: PreparedChat) -> AsyncIterator[str]:
    chunks = stream_text(
        prepared.prompt_messages,
        model=DEFAULT_MODEL,
        temperature=settings.CHAT_TEMPERATURE,
    )
    iterator = chunks.__aiter__()
    timeout = settings.LLM_FIRST_TOKEN_TIMEOUT_SECONDS

    try:
        while True:
            try:
                delta = await asyncio.wait_for(iterator.__anext__(), timeout=timeout)
            except StopAsyncIteration:
                return
            except asyncio.TimeoutError as error:
                raise TimeoutError("Model response timed out") from error

            timeout = settings.LLM_STREAM_IDLE_TIMEOUT_SECONDS
            if delta:
                yield delta
    finally:
        aclose = getattr(iterator, "aclose", None)
        if callable(aclose):
            await cast(Callable[[], Awaitable[None]], aclose)()


def finalize_stream(
    prepared: PreparedChat,
    chapter_state: ChapterStreamState | None,
    plain_chunks: list[str],
) -> StreamResult:
    if chapter_state is None:
        final_content = "".join(plain_chunks).strip()
        return StreamResult(
            final_content=final_content,
            storage_content=final_content,
            options=[],
            tail_delta=None,
        )

    combined_content = "".join(chapter_state.raw_chunks).strip()
    final_content, options = parse_chapter_response(combined_content)
    streamed_output = "".join(chapter_state.output_chunks)
    tail_delta: str | None = None

    if final_content.startswith(streamed_output):
        tail = final_content[len(streamed_output) :]
        if tail:
            tail_delta = tail
    else:
        logger.warning(
            "Chapter stream output mismatch: session_id=%s",
            prepared.session["id"],
        )

    return StreamResult(
        final_content=final_content,
        storage_content=combined_content,
        options=options,
        tail_delta=tail_delta,
    )
