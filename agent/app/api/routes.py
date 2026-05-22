from __future__ import annotations

import logging
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
from app.domain import CreditLimitError, UnauthorizedError
from app.repositories import get_user_id_from_auth_header
from app.services.chat import handle_chat
from app.services.chat.chapters import start_chapter_session
from app.services.chat.preferences import normalize_reply_length
from app.services.soulers import canonicalize_souler_name

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


@router.post("/{lang}/chat")
async def chat(
    request: Request,
    normalized_lang: Lang = Depends(require_lang),
    user_id: str = Depends(require_user_id),
):
    return await handle_chat(normalized_lang, user_id, request)


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
