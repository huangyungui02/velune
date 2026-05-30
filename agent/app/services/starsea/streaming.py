from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from typing import Any

from pydantic import ValidationError

from app.core import Lang
from app.core.errors import error_log_payload, error_message
from app.core.sse import sse_event
from app.schemas.starsea_events import (
    CompletedData,
    ConfirmRequiredData,
    ConfirmRequiredPayload,
    DeltaPayload,
    DiscardedPayload,
    DonePayload,
    ErrorData,
    ErrorPayload,
    MessageDeltaData,
    ReadyPayload,
    ResonanceMatchPayload,
    ResonanceMatchPreview,
    SettledPayload,
    SoulerResolutionResult,
    StarseaGraphEvent,
    StarseaMatchesPayload,
    UnknownEventPayload,
)
from app.services.soulers.resolution import resolve_or_enqueue_souler
from app.services.starsea.runner import resume_graph, stream_graph

logger = logging.getLogger(__name__)


async def start_starsea_stream(
    *,
    content: str,
    metadata: dict[str, Any],
    thread_id: str,
    user_id: str,
    intent: str | None,
    lang: Lang,
) -> AsyncIterator[str]:
    yield sse_event(ReadyPayload(thread_id=thread_id).model_dump(by_alias=True))
    async for event in stream_graph(
        content,
        metadata=metadata,
        thread_id=thread_id,
        intent=intent,
        user_id=user_id,
        lang=lang,
    ):
        yield sse_event(await _starsea_payload(event, lang))


async def resume_starsea_stream(
    *,
    thread_id: str,
    user_id: str,
    approved: bool,
    content: str,
    lang: Lang,
) -> AsyncIterator[str]:
    yield sse_event(ReadyPayload(thread_id=thread_id).model_dump(by_alias=True))
    async for event in resume_graph(
        thread_id=thread_id,
        user_id=user_id,
        approved=approved,
        content=content,
        lang=lang,
    ):
        yield sse_event(await _starsea_payload(event, lang))


async def emit_starsea_error(message: str) -> AsyncIterator[str]:
    yield sse_event(ErrorPayload(message=message).model_dump())


async def _starsea_payload(event: dict[str, Any], lang: Lang) -> dict[str, Any]:
    try:
        return await _map_starsea_payload(StarseaGraphEvent.model_validate(event), lang)
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to map starsea stream event: %s", error_log_payload(error))
        return ErrorPayload(message=error_message(error)).model_dump()


async def _map_starsea_payload(event: StarseaGraphEvent, lang: Lang) -> dict[str, Any]:
    match event.event:
        case "message_delta":
            data = MessageDeltaData.model_validate(_dict_data(event.data))
            return DeltaPayload(delta=data.delta).model_dump()
        case "resonance_match":
            payload = StarseaMatchesPayload(matches=await _resonance_matches(event.data, lang))
            return payload.model_dump(by_alias=True, exclude_none=True)
        case "confirm_required":
            data = ConfirmRequiredData.model_validate(_dict_data(event.data))
            payload = ConfirmRequiredPayload(thread_id=event.thread_id, content=data.content)
            return payload.model_dump(by_alias=True)
        case "completed":
            return _completed_payload(event)
        case "discarded":
            return DiscardedPayload(thread_id=event.thread_id).model_dump(by_alias=True)
        case "error":
            data = ErrorData.model_validate(_dict_data(event.data))
            return ErrorPayload(message=data.message).model_dump()
        case _:
            payload = UnknownEventPayload(thread_id=event.thread_id, data=event.data)
            return payload.model_dump(by_alias=True)


def _completed_payload(event: StarseaGraphEvent) -> dict[str, Any]:
    data = CompletedData.model_validate(_dict_data(event.data))
    display = data.display
    if isinstance(display, dict) and display.get("type") == "glimmer":
        glimmer = display.get("glimmer")
        if isinstance(glimmer, dict):
            payload = SettledPayload(thread_id=event.thread_id, glimmer=glimmer)
            return payload.model_dump(by_alias=True)

    payload = DonePayload(thread_id=event.thread_id, display=display)
    return payload.model_dump(by_alias=True)


def _dict_data(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


async def _resonance_matches(data: Any, lang: Lang) -> list[ResonanceMatchPayload]:
    if not isinstance(data, list):
        return []

    matches: list[ResonanceMatchPayload] = []
    for item in data:
        try:
            preview = ResonanceMatchPreview.model_validate(item)
        except ValidationError:
            continue

        try:
            resolved = SoulerResolutionResult.model_validate(
                await resolve_or_enqueue_souler(preview.name, lang)
            )
        except Exception as error:  # noqa: BLE001
            logger.warning(
                "Failed to resolve resonance match %s: %s",
                preview.name,
                error_log_payload(error),
            )
            resolved = SoulerResolutionResult(status="unavailable")

        matches.append(
            ResonanceMatchPayload(
                name=preview.name,
                line=preview.line,
                resolution_status=resolved.status,
                souler_id=resolved.souler_id,
                resolution_request_id=resolved.request_id,
            )
        )

    return matches
