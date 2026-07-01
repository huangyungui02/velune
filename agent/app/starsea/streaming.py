from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from typing import Any
from uuid import uuid4

from pydantic import ValidationError

from app.core.errors import error_log_data, error_message
from app.core.sse import sse_event
from app.starsea.schemas.events import (
    ConversationOptionsData,
    ConversationOptionsEvent,
    DeltaEvent,
    DoneEvent,
    ErrorData,
    ErrorEvent,
    MessageDeltaData,
    ReadyEvent,
    ResonanceMatchEvent,
    SettledEvent,
    StarseaGraphEvent,
    StarseaMatchesEvent,
    UnknownEvent,
)
from app.starsea.schemas.starsea import StarseaContent
from app.starsea.runner import stream_graph

logger = logging.getLogger(__name__)


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
        yield sse_event(ErrorEvent(message="thread_id is required when trigger is collect").model_dump())
        return

    thread_id = thread_id or str(uuid4())
    yield sse_event(ReadyEvent(thread_id=thread_id).model_dump(by_alias=True))
    async for event in stream_graph(
        content,
        lang=lang,
        metadata=metadata,
        thread_id=thread_id,
        user_id=user_id,
        is_premium=is_premium,
    ):
        yield sse_event(await _starsea_event(event))


async def emit_starsea_error(message: str) -> AsyncIterator[str]:
    yield sse_event(ErrorEvent(message=message).model_dump())


async def _starsea_event(event: dict[str, Any]) -> dict[str, Any]:
    try:
        return await _map_starsea_event(StarseaGraphEvent.model_validate(event))
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to map starsea stream event: %s", error_log_data(error))
        return ErrorEvent(message=error_message(error)).model_dump()


async def _map_starsea_event(event: StarseaGraphEvent) -> dict[str, Any]:
    match event.event:
        case "message_delta":
            data = MessageDeltaData.model_validate(_dict_data(event.data))
            return DeltaEvent(delta=data.delta, display_type=data.display_type).model_dump(
                by_alias=True,
                exclude_none=True,
            )
        case "resonance_match":
            starsea_event = StarseaMatchesEvent(matches=await _resonance_matches(event.data))
            return starsea_event.model_dump(by_alias=True, exclude_none=True)
        case "conversation_options":
            data = ConversationOptionsData.model_validate(_dict_data(event.data))
            return ConversationOptionsEvent(options=data.options).model_dump()
        case "completed":
            return _completed_event(event)
        case "error":
            data = ErrorData.model_validate(_dict_data(event.data))
            return ErrorEvent(message=data.message).model_dump()
        case _:
            starsea_event = UnknownEvent(thread_id=event.thread_id, data=event.data)
            return starsea_event.model_dump(by_alias=True)


def _completed_event(event: StarseaGraphEvent) -> dict[str, Any]:
    glimmer = _dict_data(event.data).get("glimmer")
    if isinstance(glimmer, dict):
        starsea_event = SettledEvent(thread_id=event.thread_id, glimmer=glimmer)
        return starsea_event.model_dump(by_alias=True)

    starsea_event = DoneEvent(thread_id=event.thread_id)
    return starsea_event.model_dump(by_alias=True)


def _dict_data(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


async def _resonance_matches(data: Any) -> list[ResonanceMatchEvent]:
    if not isinstance(data, list):
        return []

    matches: list[ResonanceMatchEvent] = []
    for item in data:
        try:
            matches.append(ResonanceMatchEvent.model_validate(item))
        except ValidationError:
            continue

    return matches
