from __future__ import annotations

import asyncio
import logging
from collections.abc import AsyncIterator

from fastapi import Request
from fastapi.responses import JSONResponse, StreamingResponse
from starlette.requests import ClientDisconnect

from app.core.lang import Lang
from app.domain.exceptions import CreditLimitError
from app.errors import credit_error_payload, error_log_payload, error_message
from app.infra.sse import emit_once, sse_event, sse_response
from app.services.billing import CHAT_STARDUST_COST, refund_stardust_safely
from app.services.chat.chapters.format import consume_chapter_stream_delta
from app.services.chat.post_stream import persist_chat_response
from app.services.chat.prepare import prepare_chat
from app.services.chat.streaming import (
    chapter_stream_state,
    finalize_stream,
    iter_model_deltas,
)
from app.services.chat.types import PreparedChat

logger = logging.getLogger(__name__)


async def handle_chat(
    lang: Lang,
    user_id: str,
    request: Request,
) -> StreamingResponse | JSONResponse:
    started_at = asyncio.get_running_loop().time()

    def log_stage(stage: str) -> None:
        elapsed_ms = int((asyncio.get_running_loop().time() - started_at) * 1000)
        logger.info("chat stage=%s elapsed_ms=%s", stage, elapsed_ms)

    try:
        body = await request.json()
        if not isinstance(body, dict):
            raise ValueError("Invalid request body")
        prepared = await prepare_chat(
            user_id=user_id,
            lang=lang,
            body=body,
            log_stage=log_stage,
        )
    except CreditLimitError as error:
        return sse_response(emit_once(credit_error_payload(error)))
    except ValueError as error:
        return JSONResponse({"error": str(error)}, status_code=400)
    except Exception as error:  # noqa: BLE001
        logger.error("Failed before stream start: %s", error_log_payload(error))
        return sse_response(emit_once({"type": "error", "message": error_message(error)}))

    return sse_response(_event_stream(prepared, log_stage))


def _event_stream(prepared: PreparedChat, log_stage) -> AsyncIterator[str]:
    async def generate():
        charged_in_stream = False
        try:
            yield sse_event({"type": "ready", "sessionId": prepared.session["id"]})
            log_stage("stream_opened")

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

            result = finalize_stream(prepared, chapter_state, plain_chunks)
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
        except CreditLimitError as error:
            await refund_stardust_safely(
                prepared.user_id,
                CHAT_STARDUST_COST,
                reason="chat_stream_credit_error",
            )
            yield sse_event(credit_error_payload(error))
        except (ClientDisconnect, asyncio.CancelledError):
            logger.info("Chat stream closed by client.")
            return
        except Exception as error:  # noqa: BLE001
            await refund_stardust_safely(
                prepared.user_id,
                CHAT_STARDUST_COST,
                reason="chat_stream_failed",
            )
            logger.error("Failed to process chat request: %s", error_log_payload(error))
            yield sse_event({"type": "error", "message": error_message(error)})

    return generate()
