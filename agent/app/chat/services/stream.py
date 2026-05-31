from __future__ import annotations

import asyncio
import logging
from collections.abc import AsyncIterator

from starlette.requests import ClientDisconnect

from app.core.config import get_settings
from app.core.errors import error_log_payload, error_message
from app.core.sse import sse_event
from app.core.llm import DEFAULT_MODEL, stream_text

from app.chat.chat_response import (
    ChatStreamState,
    consume_chat_stream_delta,
    parse_chat_response,
)
from app.chat.services.types import (
    PreparedChat,
    StageLogger,
)
from .persist import save_response

logger = logging.getLogger(__name__)
settings = get_settings()


def stream_events(
    prepared: PreparedChat,
    log_stage: StageLogger,
) -> AsyncIterator[str]:
    async def generate() -> AsyncIterator[str]:
        try:
            yield sse_event({"type": "ready", "sessionId": prepared.session["id"]})
            log_stage("stream_opened")

            option_state = ChatStreamState(
                raw_chunks=[],
                output_chunks=[],
                pending="",
                phase="streaming_content",
            )
            async for delta in stream_text(
                prepared.prompt_messages,
                model=DEFAULT_MODEL,
                temperature=settings.CHAT_TEMPERATURE,
            ):
                visible_delta = consume_chat_stream_delta(option_state, delta)
                if visible_delta:
                    yield sse_event({"type": "delta", "delta": visible_delta})

            storage_content = "".join(option_state.raw_chunks).strip()
            final_content, options = parse_chat_response(storage_content)
            streamed_content = "".join(option_state.output_chunks)

            if final_content.startswith(streamed_content):
                tail_delta = final_content[len(streamed_content) :]
                if tail_delta:
                    yield sse_event({"type": "delta", "delta": tail_delta})
            else:
                logger.warning(
                    "Chat stream output mismatch: session_id=%s",
                    prepared.session["id"],
                )

            if not final_content or not storage_content:
                raise ValueError("Empty assistant response")
            log_stage("model_completed")

            assistant_message, generated_title = await save_response(
                prepared,
                storage_content=storage_content,
                final_content=final_content,
            )
            log_stage("assistant_message_inserted")

            if options:
                yield sse_event({"type": "options", "options": options})

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
