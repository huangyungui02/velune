from __future__ import annotations

from collections.abc import AsyncIterator
from typing import Any
from uuid import uuid4

from app.core.sse import sse_event
from app.starsea.schemas.events import ErrorEvent, ReadyEvent
from app.starsea.schemas.model import ErrorContent, ReadyContent
from app.starsea.schemas.starsea import StarseaContent
from app.starsea.runner import stream_graph


async def start_starsea_stream(
    *,
    content: StarseaContent,
    metadata: dict[str, Any],
    thread_id: str | None,
    user_id: str,
    is_premium: bool,
    lang: str,
) -> AsyncIterator[str]:
    if content.type == "trigger" and content.content == "collect" and thread_id is None:
        event = ErrorEvent(
            content=ErrorContent(message="thread_id is required when trigger is collect")
        )
        yield sse_event(event)
        return

    thread_id = thread_id or str(uuid4())
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


async def emit_starsea_error(message: str) -> AsyncIterator[str]:
    yield sse_event(ErrorEvent(content=ErrorContent(message=message)))
