from __future__ import annotations

import asyncio
import logging

from fastapi.responses import StreamingResponse

from app.core.errors import error_log_payload, error_message
from app.core.sse import emit_once, sse_response
from app.schemas.common import Lang
from app.services.chat.preferences import ReplyLength
from app.services.chat.prepare import prepare_chat
from app.services.chat.streaming import stream_chat_events

logger = logging.getLogger(__name__)


async def handle_chat(
    *,
    lang: Lang,
    user_id: str,
    session_id: str,
    souler_id: str,
    chapter_id: str,
    content: str,
    reply_length: ReplyLength,
) -> StreamingResponse:
    started_at = asyncio.get_running_loop().time()

    def log_stage(stage: str) -> None:
        elapsed_ms = int((asyncio.get_running_loop().time() - started_at) * 1000)
        logger.info("chat stage=%s elapsed_ms=%s", stage, elapsed_ms)

    try:
        prepared = await prepare_chat(
            user_id=user_id,
            lang=lang,
            session_id=session_id,
            souler_id=souler_id,
            chapter_id=chapter_id,
            content=content,
            reply_length=reply_length,
            log_stage=log_stage,
        )
    except ValueError:
        raise
    except Exception as error:  # noqa: BLE001
        logger.error("Failed before stream start: %s", error_log_payload(error))
        return sse_response(emit_once({"type": "error", "message": error_message(error)}))

    return sse_response(stream_chat_events(prepared, log_stage))
