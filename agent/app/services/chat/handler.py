from __future__ import annotations

import asyncio
import logging

from fastapi import Request
from fastapi.responses import JSONResponse, StreamingResponse

from app.core import Lang
from app.api.http import error_response, required_json_body
from app.core.errors import error_log_payload, error_message
from app.core.sse import emit_once, sse_response
from app.services.chat.prepare import prepare_chat
from app.services.chat.streaming import stream_chat_events

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
        body = await required_json_body(request)
        prepared = await prepare_chat(
            user_id=user_id,
            lang=lang,
            body=body,
            log_stage=log_stage,
        )
    except ValueError as error:
        return error_response(str(error))
    except Exception as error:  # noqa: BLE001
        logger.error("Failed before stream start: %s", error_log_payload(error))
        return sse_response(emit_once({"type": "error", "message": error_message(error)}))

    return sse_response(stream_chat_events(prepared, log_stage))
