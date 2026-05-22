from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from dataclasses import dataclass

from app.config import get_settings
from app.domain import Session
from app.infra.llm import DEFAULT_MODEL, stream_text
from app.infra.streaming import stream_with_timeout
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
    async for delta in stream_with_timeout(
        stream_text(
            prepared.prompt_messages,
            model=DEFAULT_MODEL,
            temperature=settings.CHAT_TEMPERATURE,
        ),
        first_chunk_timeout=settings.LLM_FIRST_TOKEN_TIMEOUT_SECONDS,
        idle_timeout=settings.LLM_STREAM_IDLE_TIMEOUT_SECONDS,
    ):
        if delta:
            yield delta


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
