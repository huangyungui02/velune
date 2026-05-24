from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse

from app.api.http import (
    credit_limit_response,
    error_response,
    json_body,
    required_json_body,
)
from app.core import Lang, normalize_lang
from app.core.errors import error_log_payload, error_message
from app.core.sse import sse_event, sse_response
from app.domain import CreditLimitError, UnauthorizedError
from app.repositories import get_glimmer_by_id, get_user_id_from_auth_header
from app.services.chat import handle_chat
from app.services.chat.chapters import start_chapter_session
from app.services.chat.preferences import normalize_reply_length
from app.services.soulers import canonicalize_souler_name
from app.services.starsea import stream_graph

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
        glimmer_id = _require_uuid(body.get("glimmerId"), "glimmerId")
        metadata = body.get("metadata")
        if metadata is None:
            metadata = {}
        if not isinstance(metadata, dict):
            raise ValueError("metadata must be an object")

        glimmer = await get_glimmer_by_id(user_id, glimmer_id)
        if glimmer is None:
            raise ValueError("Glimmer not found")

        content = str(glimmer.get("content") or "").strip()
        fallback = body.get("content")
        if not content and isinstance(fallback, str):
            content = fallback.strip()
        if not content:
            raise ValueError("Glimmer content cannot be empty")

        return sse_response(_stream_starsea(content, metadata, glimmer_id))
    except ValueError as error:
        return error_response(str(error))
    except Exception as error:  # noqa: BLE001
        logger.error("Failed before starsea stream start: %s", error_log_payload(error))
        return sse_response(_emit_starsea_error(error_message(error)))


@router.post("/{lang}/chat")
async def chat(
    request: Request,
    normalized_lang: Lang = Depends(require_lang),
    user_id: str = Depends(require_user_id),
):
    return await handle_chat(normalized_lang, user_id, request)


def _require_uuid(value: Any, field: str) -> str:
    try:
        return str(UUID(str(value)))
    except (TypeError, ValueError) as error:
        raise ValueError(f"{field} must be a valid uuid") from error


async def _stream_starsea(
    content: str,
    metadata: dict[str, Any],
    thread_id: str,
) -> AsyncIterator[str]:
    yield sse_event({"type": "ready", "threadId": thread_id})
    async for event in stream_graph(content, metadata=metadata, thread_id=thread_id):
        payload = _starsea_payload(event)
        yield sse_event(payload)


async def _emit_starsea_error(message: str) -> AsyncIterator[str]:
    yield sse_event({"type": "error", "message": message})


def _starsea_payload(event: dict[str, Any]) -> dict[str, Any]:
    event_name = str(event.get("event") or "")
    thread_id = str(event.get("thread_id") or "")
    data = event.get("data")

    if event_name == "message_delta" and isinstance(data, dict):
        return {"type": "delta", "delta": str(data.get("delta") or "")}
    if event_name == "thought_matches":
        return {"type": "thought_matches", "matches": data if isinstance(data, list) else []}
    if event_name == "completed" and isinstance(data, dict):
        display = data.get("display")
        return {"type": "done", "threadId": thread_id, "display": display}
    if event_name == "error" and isinstance(data, dict):
        return {"type": "error", "message": str(data.get("message") or "Starsea failed")}

    return {"type": "event", "threadId": thread_id, "data": data}


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
    except CreditLimitError as error:
        return credit_limit_response(error)
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to start chapter session: %s", error_log_payload(error))
        return error_response(error_message(error))


@router.post("/{lang}/soulers/canonicalize")
async def canonicalize_souler_name_route(
    request: Request,
    normalized_lang: Lang = Depends(require_lang),
    _: str = Depends(require_user_id),
):
    try:
        body = await required_json_body(request)
        raw_name = body.get("name")
        if not isinstance(raw_name, str) or not raw_name.strip():
            raise ValueError("Souler name cannot be empty")
        if len(raw_name) > 128:
            raise ValueError("Souler name is too long")

        canonical_name = await canonicalize_souler_name(raw_name, normalized_lang)
        return JSONResponse({"canonical_name": canonical_name}, status_code=200)
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to canonicalize souler: %s", error_log_payload(error))
        return error_response(error_message(error))
