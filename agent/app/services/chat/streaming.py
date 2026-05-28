from __future__ import annotations

import asyncio
import logging
from collections.abc import AsyncIterator, Awaitable, Callable
from dataclasses import dataclass
from typing import cast

from starlette.requests import ClientDisconnect

from app.core.config import get_settings
from app.core.errors import error_log_payload, error_message
from app.core.llm import DEFAULT_MODEL, stream_text
from app.core.sse import sse_event
from app.domain import Session
from app.services.chat.chapters.response import (
    ChapterStreamState,
    consume_chapter_stream_delta,
    parse_chapter_response,
)
from app.services.chat.post_stream import persist_chat_response
from app.services.chat.types import PreparedChat

logger = logging.getLogger(__name__)
settings = get_settings()
StageLogger = Callable[[str], None]


@dataclass(frozen=True)
class StreamResult:
    final_content: str
    storage_content: str
    options: list[str]
    tail_delta: str | None


@dataclass(frozen=True)
class ResponseComplete:
    result: StreamResult


type ResponseStreamItem = str | ResponseComplete


def chapter_stream_state(session: Session) -> ChapterStreamState | None:
    if not session.get("chapter"):
        return None
    return ChapterStreamState(
        raw_chunks=[],
        output_chunks=[],
        pending="",
        phase="streaming_content",
    )


def stream_chat_events(
    prepared: PreparedChat,
    log_stage: StageLogger,
) -> AsyncIterator[str]:
    async def generate() -> AsyncIterator[str]:
        try:
            yield sse_event({"type": "ready", "sessionId": prepared.session["id"]})
            log_stage("stream_opened")

            result: StreamResult | None = None
            async for item in iter_response_stream(prepared):
                if isinstance(item, ResponseComplete):
                    result = item.result
                else:
                    yield item

            if result is None:
                raise ValueError("Missing assistant response")
            if not result.final_content or not result.storage_content:
                raise ValueError("Empty assistant response")
            log_stage("model_completed")

            if result.tail_delta:
                yield sse_event({"type": "delta", "delta": result.tail_delta})

            assistant_message, generated_title = await persist_chat_response(
                prepared,
                storage_content=result.storage_content,
                final_content=result.final_content,
            )
            log_stage("assistant_message_inserted")

            if result.options:
                yield sse_event({"type": "options", "options": result.options})

            log_stage("stream_done")
            yield sse_event(
                {
                    "type": "done",
                    "sessionId": prepared.session["id"],
                    "title": generated_title,
                    "assistantMessage": {
                        "id": assistant_message["id"],
                        "createdAt": assistant_message["created_at"],
                    },
                }
            )
        except (ClientDisconnect, asyncio.CancelledError):
            logger.info("Chat stream closed by client.")
            return
        except Exception as error:  # noqa: BLE001
            logger.error("Failed to process chat request: %s", error_log_payload(error))
            yield sse_event({"type": "error", "message": error_message(error)})

    return generate()


async def iter_response_stream(
    prepared: PreparedChat,
) -> AsyncIterator[ResponseStreamItem]:
    chapter_state = chapter_stream_state(prepared.session)
    plain_chunks: list[str] = []

    async for delta in iter_model_deltas(prepared):
        if chapter_state is None:
            plain_chunks.append(delta)
            yield sse_event({"type": "delta", "delta": delta})
            continue

        output_delta = consume_chapter_stream_delta(chapter_state, delta)
        if output_delta:
            plain_chunks.append(output_delta)
            yield sse_event({"type": "delta", "delta": output_delta})

    yield ResponseComplete(finalize_stream(prepared, chapter_state, plain_chunks))


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
