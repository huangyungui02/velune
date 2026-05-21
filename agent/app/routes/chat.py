from __future__ import annotations

import asyncio
import logging
from uuid import UUID

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from app.chat.preferences import normalize_reply_length
from app.shared import Lang, normalize_lang
from app.errors import CreditLimitError, UnauthorizedError, error_log_payload, error_message
from app.chat import handle_chat
from app.chat.chapters import start_chapter_session
from app.soulers.canonical import canonicalize_souler_name
from app.repositories import get_user_id_from_auth_header

logger = logging.getLogger(__name__)
router = APIRouter()


class CanonicalizeSoulerRequest(BaseModel):
    name: str = Field(min_length=1, max_length=128)


@router.post("/{lang}/chat")
async def chat(lang: Lang, request: Request):
    return await handle_chat(lang, request)


@router.post("/{lang}/soulers/{souler_id}/chapters/{chapter_id}/start")
async def start_chapter_session_route(
    lang: Lang,
    souler_id: UUID,
    chapter_id: UUID,
    request: Request,
):
    try:
        lang = normalize_lang(lang)
    except ValueError as error:
        return JSONResponse({"error": str(error)}, status_code=400)

    try:
        user_id = await asyncio.to_thread(
            get_user_id_from_auth_header,
            request.headers.get("Authorization"),
        )
    except UnauthorizedError:
        return JSONResponse({"error": "Unauthorized"}, status_code=401)
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to validate auth: %s", error_log_payload(error))
        return JSONResponse({"error": error_message(error)}, status_code=400)

    try:
        try:
            body = await request.json()
        except Exception:  # noqa: BLE001
            body = {}
        if not isinstance(body, dict):
            body = {}
        reply_length = normalize_reply_length(body.get("replyLength"))
        payload = await start_chapter_session(
            user_id=user_id,
            souler_id=souler_id,
            chapter_id=chapter_id,
            lang=lang,
            reply_length=reply_length,
        )
        return JSONResponse(payload, status_code=200)
    except CreditLimitError as error:
        return JSONResponse(
            {
                "code": error.code,
                "error": str(error),
            },
            status_code=402,
        )
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to start chapter session: %s", error_log_payload(error))
        return JSONResponse({"error": error_message(error)}, status_code=400)


@router.post("/{lang}/soulers/canonicalize")
async def canonicalize_souler_name_route(
    lang: Lang,
    payload: CanonicalizeSoulerRequest,
    request: Request,
):
    try:
        lang = normalize_lang(lang)
    except ValueError as error:
        return JSONResponse({"error": str(error)}, status_code=400)

    try:
        await asyncio.to_thread(
            get_user_id_from_auth_header,
            request.headers.get("Authorization"),
        )
    except UnauthorizedError:
        return JSONResponse({"error": "Unauthorized"}, status_code=401)
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to validate auth: %s", error_log_payload(error))
        return JSONResponse({"error": error_message(error)}, status_code=400)

    try:
        canonical_name = await canonicalize_souler_name(payload.name, lang)
        return JSONResponse({"canonical_name": canonical_name}, status_code=200)
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to canonicalize souler: %s", error_log_payload(error))
        return JSONResponse({"error": error_message(error)}, status_code=400)
