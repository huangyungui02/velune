from __future__ import annotations

import asyncio
import logging

from fastapi import Request
from fastapi.responses import JSONResponse, StreamingResponse
from starlette.requests import ClientDisconnect

from app.chapter_reply import parse_chapter_combined_response
from app.config import get_settings
from app.echo_nodes import SUPPORTED_LANGS
from app.echo_logic import Lang
from app.errors import (
    CreditLimitError,
    credit_error_payload,
    error_log_payload,
    error_message,
)
from app.llm import stream_text
from app.sse import emit_once, sse_event, sse_response
from app.supabase_repo import (
    create_or_update_resonance,
    insert_message,
    touch_session,
    update_session_title,
)

from .prepare import prepare_chat_request
from .shared import (
    CHAT_CREDIT_COST,
    CHAT_MODEL,
    ChapterStreamState,
    consume_chapter_stream_delta,
    generate_session_title,
    refund_stardust_safely,
    run_blocking,
    stream_with_timeout,
)

logger = logging.getLogger(__name__)
settings = get_settings()


async def handle_chat(lang: Lang, request: Request) -> StreamingResponse:
    normalized_lang = str(lang).strip().lower()
    if normalized_lang not in SUPPORTED_LANGS:
        return JSONResponse(
            {"error": "Invalid lang, must be one of: en, chs"},
            status_code=400,
        )

    started_at = asyncio.get_running_loop().time()

    def log_stage(stage: str) -> None:
        elapsed_ms = int((asyncio.get_running_loop().time() - started_at) * 1000)
        logger.info("chat stage=%s elapsed_ms=%s", stage, elapsed_ms)

    try:
        log_stage("request_received")
        prepared = await prepare_chat_request(request, normalized_lang, log_stage)
    except CreditLimitError as error:
        return sse_response(emit_once(credit_error_payload(error)))
    except ValueError as error:
        return JSONResponse({"error": str(error)}, status_code=400)
    except Exception as error:  # noqa: BLE001
        logger.error("Failed before stream start: %s", error_log_payload(error))
        return sse_response(emit_once({"type": "error", "message": error_message(error)}))

    async def event_stream():
        should_refund_on_failure = True
        try:
            yield sse_event({"type": "ready", "sessionId": prepared.session["id"]})
            log_stage("stream_opened")

            chapter_stream_state: ChapterStreamState | None = None
            assistant_chunks: list[str] = []
            assistant_storage_content: str | None = None
            options: list[str] = []
            if prepared.session.get("chapter"):
                chapter_stream_state = ChapterStreamState(
                    raw_chunks=[],
                    output_chunks=[],
                    pending="",
                    phase="streaming_content",
                )

            async for delta in stream_with_timeout(
                stream_text(
                    prepared.prompt_messages,
                    model=CHAT_MODEL,
                    temperature=settings.CHAT_TEMPERATURE,
                ),
                first_chunk_timeout=settings.LLM_FIRST_TOKEN_TIMEOUT_SECONDS,
                idle_timeout=settings.LLM_STREAM_IDLE_TIMEOUT_SECONDS,
            ):
                if not delta:
                    continue

                if chapter_stream_state is None:
                    assistant_chunks.append(delta)
                    yield sse_event({"type": "delta", "delta": delta})
                    continue

                output_delta = consume_chapter_stream_delta(chapter_stream_state, delta)
                if output_delta:
                    assistant_chunks.append(output_delta)
                    yield sse_event({"type": "delta", "delta": output_delta})

            if chapter_stream_state is None:
                final_content = "".join(assistant_chunks).strip()
                assistant_storage_content = final_content
            else:
                combined_content = "".join(chapter_stream_state.raw_chunks).strip()
                final_content, options = parse_chapter_combined_response(combined_content)
                assistant_storage_content = combined_content

                streamed_output = "".join(chapter_stream_state.output_chunks)
                if final_content.startswith(streamed_output):
                    tail = final_content[len(streamed_output) :]
                    if tail:
                        assistant_chunks.append(tail)
                        yield sse_event({"type": "delta", "delta": tail})
                else:
                    logger.warning(
                        "Chapter stream output mismatch: session_id=%s",
                        prepared.session["id"],
                    )

            if not final_content:
                raise ValueError("Empty assistant response")
            if not assistant_storage_content:
                raise ValueError("Empty assistant storage content")
            log_stage("model_completed")

            assistant_message = await run_blocking(
                "Insert assistant message",
                insert_message,
                prepared.user_id,
                prepared.session["soulerId"],
                prepared.session["id"],
                "assistant",
                assistant_storage_content,
            )
            log_stage("assistant_message_inserted")

            generated_title: str | None = None
            if prepared.is_new_session and prepared.should_generate_title:
                generated_title = await asyncio.wait_for(
                    generate_session_title(
                        prepared.content,
                        final_content,
                        prepared.lang,
                        model=CHAT_MODEL,
                    ),
                    timeout=settings.POST_STREAM_TIMEOUT_SECONDS,
                )
                await run_blocking(
                    "Update session title",
                    update_session_title,
                    prepared.user_id,
                    prepared.session["id"],
                    generated_title,
                    timeout=settings.POST_STREAM_TIMEOUT_SECONDS,
                )
                log_stage("title_updated")

            if options:
                yield sse_event({"type": "options", "options": options})

            await run_blocking(
                "Touch session",
                touch_session,
                prepared.user_id,
                prepared.session["id"],
                timeout=settings.POST_STREAM_TIMEOUT_SECONDS,
            )
            await run_blocking(
                "Update resonance",
                create_or_update_resonance,
                prepared.user_id,
                prepared.session["soulerId"],
                prepared.session["id"],
                timeout=settings.POST_STREAM_TIMEOUT_SECONDS,
            )
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
            should_refund_on_failure = False
        except CreditLimitError as error:
            if should_refund_on_failure:
                await refund_stardust_safely(
                    prepared.user_id,
                    CHAT_CREDIT_COST,
                    reason="chat_stream_credit_error",
                )
            yield sse_event(credit_error_payload(error))
        except (ClientDisconnect, asyncio.CancelledError):
            logger.info("Chat stream closed by client.")
            return
        except Exception as error:  # noqa: BLE001
            if should_refund_on_failure:
                await refund_stardust_safely(
                    prepared.user_id,
                    CHAT_CREDIT_COST,
                    reason="chat_stream_failed",
                )
            logger.error("Failed to process chat request: %s", error_log_payload(error))
            yield sse_event({"type": "error", "message": error_message(error)})

    return sse_response(event_stream())
