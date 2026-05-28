from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from typing import Any
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse

from app.api.http import (
    error_response,
    json_body,
    required_json_body,
)
from app.core import Lang, normalize_lang
from app.core.errors import error_log_payload, error_message
from app.core.sse import sse_event, sse_response
from app.domain import UnauthorizedError
from app.repositories import get_user_id_from_auth_header
from app.services.chat import handle_chat
from app.services.chat.chapters import start_chapter_session
from app.services.chat.preferences import normalize_reply_length
from app.services.starsea import resume_graph, stream_graph

logger = logging.getLogger(__name__)
router = APIRouter()


async def require_lang(lang: str) -> Lang:
    try:
        return normalize_lang(lang)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


async def require_user_id(request: Request) -> str:
    try:
        return await get_user_id_from_auth_header(request.headers.get("Authorization"))
    except UnauthorizedError as error:
        raise HTTPException(status_code=401, detail="Unauthorized") from error
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to validate auth: %s", error_log_payload(error))
        raise HTTPException(status_code=400, detail=error_message(error)) from error


@router.post("/starsea")
async def starsea(
    request: Request,
    user_id: str = Depends(require_user_id),
):
    try:
        body = await required_json_body(request)
        metadata = body.get("metadata")
        if metadata is None:
            metadata = {}
        if not isinstance(metadata, dict):
            raise ValueError("metadata must be an object")

        intent = _optional_intent(body.get("intent"))
        thread_id = _optional_uuid(body.get("threadId"), "threadId") or str(uuid4())
        raw_content = body.get("content")
        content = raw_content.strip() if isinstance(raw_content, str) else ""
        if intent == "collect" and body.get("threadId") is None:
            raise ValueError("threadId is required when intent is collect")
        if intent != "collect" and not content:
            raise ValueError("content cannot be empty")

        return sse_response(_stream_starsea(content, metadata, thread_id, user_id, intent))
    except ValueError as error:
        return error_response(str(error))
    except Exception as error:  # noqa: BLE001
        logger.error("Failed before starsea stream start: %s", error_log_payload(error))
        return sse_response(_emit_starsea_error(error_message(error)))


@router.post("/starsea/resume")
async def starsea_resume(
    request: Request,
    user_id: str = Depends(require_user_id),
):
    try:
        body = await required_json_body(request)
        thread_id = _optional_uuid(body.get("threadId"), "threadId")
        if thread_id is None:
            raise ValueError("threadId is required")

        approved = body.get("approved")
        if not isinstance(approved, bool):
            raise ValueError("approved must be a boolean")

        raw_content = body.get("content")
        content = raw_content.strip() if isinstance(raw_content, str) else ""
        if approved and not content:
            raise ValueError("content cannot be empty")

        return sse_response(_stream_starsea_resume(thread_id, user_id, approved, content))
    except ValueError as error:
        return error_response(str(error))
    except Exception as error:  # noqa: BLE001
        logger.error("Failed before starsea resume stream start: %s", error_log_payload(error))
        return sse_response(_emit_starsea_error(error_message(error)))


@router.post("/{lang}/chat")
async def chat(
    request: Request,
    normalized_lang: Lang = Depends(require_lang),
    user_id: str = Depends(require_user_id),
):
    return await handle_chat(normalized_lang, user_id, request)


def _optional_uuid(value: Any, field: str) -> str | None:
    if value is None:
        return None
    try:
        return str(UUID(str(value)))
    except (TypeError, ValueError) as error:
        raise ValueError(f"{field} must be a valid uuid") from error


def _optional_intent(value: Any) -> str | None:
    if value is None:
        return None
    if value == "collect":
        return "collect"
    raise ValueError("intent must be collect")


async def _stream_starsea(
    content: str,
    metadata: dict[str, Any],
    thread_id: str,
    user_id: str,
    intent: str | None,
) -> AsyncIterator[str]:
    yield sse_event({"type": "ready", "threadId": thread_id})
    async for event in stream_graph(
        content,
        metadata=metadata,
        thread_id=thread_id,
        intent=intent,
        user_id=user_id,
    ):
        try:
            payload = await _starsea_payload(event)
        except Exception as error:  # noqa: BLE001
            logger.error("Failed to map starsea stream event: %s", error_log_payload(error))
            payload = {"type": "error", "message": error_message(error)}
        yield sse_event(payload)


async def _stream_starsea_resume(
    thread_id: str,
    user_id: str,
    approved: bool,
    content: str,
) -> AsyncIterator[str]:
    yield sse_event({"type": "ready", "threadId": thread_id})
    async for event in resume_graph(
        thread_id=thread_id,
        user_id=user_id,
        approved=approved,
        content=content,
    ):
        try:
            payload = await _starsea_payload(event)
        except Exception as error:  # noqa: BLE001
            logger.error("Failed to map starsea resume event: %s", error_log_payload(error))
            payload = {"type": "error", "message": error_message(error)}
        yield sse_event(payload)


async def _emit_starsea_error(message: str) -> AsyncIterator[str]:
    yield sse_event({"type": "error", "message": message})


async def _starsea_payload(event: dict[str, Any]) -> dict[str, Any]:
    event_name = str(event.get("event") or "")
    thread_id = str(event.get("thread_id") or "")
    data = event.get("data")

    if event_name == "message_delta" and isinstance(data, dict):
        return {"type": "delta", "delta": str(data.get("delta") or "")}
    if event_name == "resonance_match":
        return {"type": "resonance_match", "matches": _resonance_matches(data)}
    if event_name == "confirm_required" and isinstance(data, dict):
        return {
            "type": "confirm_required",
            "threadId": thread_id,
            "content": str(data.get("content") or ""),
        }
    if event_name == "completed" and isinstance(data, dict):
        display = data.get("display")
        if isinstance(display, dict) and display.get("type") == "glimmer":
            glimmer = display.get("glimmer")
            if isinstance(glimmer, dict):
                return {"type": "settled", "threadId": thread_id, "glimmer": glimmer}
        return {"type": "done", "threadId": thread_id, "display": display}
    if event_name == "discarded":
        return {"type": "discarded", "threadId": thread_id}
    if event_name == "error" and isinstance(data, dict):
        return {"type": "error", "message": str(data.get("message") or "Starsea failed")}

    return {"type": "event", "threadId": thread_id, "data": data}


def _resonance_matches(data: Any) -> list[dict[str, str]]:
    if not isinstance(data, list):
        return []

    matches: list[dict[str, str]] = []
    for item in data:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name") or "").strip()
        line = str(item.get("line") or item.get("whisper") or "").strip()
        if name and line:
            matches.append({"name": name, "line": line})
    return matches


@router.post("/{lang}/soulers/{souler_id}/chapters/{chapter_id}/start")
async def start_chapter_session_route(
    souler_id: UUID,
    chapter_id: UUID,
    request: Request,
    normalized_lang: Lang = Depends(require_lang),
    user_id: str = Depends(require_user_id),
):
    try:
        body = await json_body(request)
        reply_length = normalize_reply_length(body.get("replyLength"))
        payload = await start_chapter_session(
            user_id=user_id,
            souler_id=souler_id,
            chapter_id=chapter_id,
            lang=normalized_lang,
            reply_length=reply_length,
        )
        return JSONResponse(payload, status_code=200)
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to start chapter session: %s", error_log_payload(error))
        return error_response(error_message(error))
