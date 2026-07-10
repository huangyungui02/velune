from __future__ import annotations

import asyncio
import logging
from collections.abc import AsyncIterator

from starlette.requests import ClientDisconnect

from app.auth.billing import is_user_premium
from app.chat.repositories.messages import get_recent_messages, insert_message
from app.chat.repositories.session import create_session, delete_session, get_session_by_id
from app.chat.services.sessions import sync_session_activity
from app.core.config import get_settings
from app.core.errors import error_log_data, error_message
from app.core.llm import model_for_premium, stream_text
from app.core.sse import sse_event, sse_response

from .prompts import folio_system_prompt
from .repositories import Folio, get_public_folio
from .response import FolioStreamState, consume_folio_stream_delta, parse_folio_response

logger = logging.getLogger(__name__)
settings = get_settings()


async def start_folio_response(*, user_id: str, folio_id: str, lang: str):
    folio = await get_public_folio(folio_id, lang)
    session_id = await create_session(
        user_id,
        folio["souler_id"],
        title=folio["title"],
        folio_id=folio["id"],
    )
    return sse_response(
        _stream_folio_response(
            user_id=user_id,
            folio=folio,
            session_id=session_id,
            lang=lang,
            user_content="开始" if lang == "zh" else "start",
            persist_user_message=False,
            delete_on_failure=True,
        )
    )


async def continue_folio_response(
    *,
    user_id: str,
    folio_id: str,
    session_id: str,
    content: str,
    lang: str,
):
    folio = await get_public_folio(folio_id, lang)
    session = await get_session_by_id(user_id, session_id, lang)
    if session.get("folio_id") != folio["id"]:
        raise ValueError("Folio session not found")
    if session["souler_id"] != folio["souler_id"]:
        raise ValueError("Folio session does not match folio")

    return sse_response(
        _stream_folio_response(
            user_id=user_id,
            folio=folio,
            session_id=session_id,
            lang=lang,
            user_content=content,
            persist_user_message=True,
            delete_on_failure=False,
        )
    )


def _stream_folio_response(
    *,
    user_id: str,
    folio: Folio,
    session_id: str,
    lang: str,
    user_content: str,
    persist_user_message: bool,
    delete_on_failure: bool,
) -> AsyncIterator[str]:
    async def generate() -> AsyncIterator[str]:
        assistant_written = False
        try:
            history = await get_recent_messages(user_id, session_id)
            if persist_user_message:
                await insert_message(
                    user_id,
                    folio["souler_id"],
                    session_id,
                    "user",
                    user_content,
                )

            prompt_messages = [
                {"role": "system", "content": folio_system_prompt(folio["prompt"], lang)},
                *[
                    {
                        "role": "assistant" if item["role"] == "assistant" else "user",
                        "content": item["content"],
                    }
                    for item in history
                ],
                {"role": "user", "content": user_content},
            ]
            model = model_for_premium(await is_user_premium(user_id))
            yield sse_event({"type": "ready", "sessionId": session_id})

            state = FolioStreamState()
            async for delta in stream_text(
                prompt_messages,
                model=model,
                temperature=settings.CHAT_TEMPERATURE,
            ):
                visible_delta = consume_folio_stream_delta(state, delta)
                if visible_delta:
                    yield sse_event({"type": "delta", "delta": visible_delta})

            storage_content = "".join(state.raw_chunks).strip()
            final_content, options, ended = parse_folio_response(storage_content)
            streamed_content = "".join(state.output_chunks).rstrip()
            if final_content.startswith(streamed_content):
                tail_delta = final_content[len(streamed_content) :]
                if tail_delta:
                    yield sse_event({"type": "delta", "delta": tail_delta})
            else:
                logger.warning("Folio stream output mismatch: session_id=%s", session_id)

            assistant_message = await insert_message(
                user_id,
                folio["souler_id"],
                session_id,
                "assistant",
                storage_content,
            )
            assistant_written = True
            await sync_session_activity(user_id, session_id, folio["souler_id"])

            if options:
                yield sse_event({"type": "options", "options": options})
            yield sse_event(
                {
                    "type": "done",
                    "sessionId": session_id,
                    "ended": ended,
                    "assistantMessage": {
                        "id": assistant_message["id"],
                        "createdAt": assistant_message["created_at"],
                    },
                }
            )
        except (ClientDisconnect, asyncio.CancelledError):
            logger.info("Folio stream closed by client: session_id=%s", session_id)
        except Exception as error:  # noqa: BLE001
            logger.error("Failed to process folio response: %s", error_log_data(error))
            yield sse_event({"type": "error", "message": error_message(error)})
        finally:
            if delete_on_failure and not assistant_written:
                try:
                    await delete_session(user_id, session_id)
                except Exception as cleanup_error:  # noqa: BLE001
                    logger.warning(
                        "Failed to cleanup folio session: session_id=%s error=%s",
                        session_id,
                        error_log_data(cleanup_error),
                    )

    return generate()
