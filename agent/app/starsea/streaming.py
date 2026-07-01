from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from typing import Any
from uuid import uuid4

from app.auth.billing import is_user_premium
from app.core.errors import error_log_data, error_message
from app.core.sse import sse_event
from app.starsea.schemas.events import ErrorEvent, ReadyEvent
from app.starsea.schemas.model import ErrorContent, ReadyContent
from app.starsea.schemas.starsea import StarseaContent
from app.starsea.runner import stream_graph

logger = logging.getLogger(__name__)


async def start_starsea_stream(
    *,
    content: StarseaContent,
    metadata: dict[str, Any],
    thread_id: str | None,
    user_id: str,
    lang: str,
) -> AsyncIterator[str]:
    try:
        if content.type == "trigger" and content.content == "collect" and thread_id is None:
            event = ErrorEvent(
                content=ErrorContent(message="thread_id is required when trigger is collect")
            )
            yield sse_event(event)
            return

        thread_id = thread_id or str(uuid4())
        is_premium = await is_user_premium(user_id)
        yield sse_event(ReadyEvent(content=ReadyContent(thread_id=thread_id)))
        async for event in stream_graph(
            content,
            lang=lang,
            metadata=metadata,
            thread_id=thread_id,
            user_id=user_id,
            is_premium=is_premium,
        ):
            yield sse_event(event)
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to process starsea stream: %s", error_log_data(error))
        yield sse_event(ErrorEvent(content=ErrorContent(message=error_message(error))))
