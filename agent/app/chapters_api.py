from __future__ import annotations

import asyncio
import logging
from uuid import UUID

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

from app.echo_nodes import SUPPORTED_LANGS
from app.echo_logic import Lang
from app.errors import CreditLimitError, UnauthorizedError, error_log_payload, error_message
from app.services.chapters import start_chapter_session, start_generation
from app.supabase_repo import get_user_id_from_auth_header

router = APIRouter()
logger = logging.getLogger(__name__)


def _is_invalid_lang(lang: Lang) -> bool:
    return str(lang).strip().lower() not in SUPPORTED_LANGS


@router.post("/{lang}/soulers/{souler_id}/chapters/generate")
async def generate_chapters(lang: Lang, souler_id: UUID, request: Request):
    lang = str(lang).strip().lower()
    if _is_invalid_lang(lang):
        return JSONResponse(
            {"error": "Invalid lang, must be one of: en, chs"},
            status_code=400,
        )

    try:
        await asyncio.to_thread(
            get_user_id_from_auth_header,
            request.headers.get("Authorization"),
        )
        status_code, payload = await start_generation(str(souler_id), lang)
        return JSONResponse(payload, status_code=status_code)
    except UnauthorizedError:
        return JSONResponse({"error": "Unauthorized"}, status_code=401)
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to generate chapters: %s", error_log_payload(error))
        return JSONResponse({"error": error_message(error)}, status_code=400)


@router.post("/{lang}/soulers/{souler_id}/chapters/{chapter_id}/start")
async def start_chapter_session_route(
    lang: Lang,
    souler_id: UUID,
    chapter_id: UUID,
    request: Request,
):
    lang = str(lang).strip().lower()
    if _is_invalid_lang(lang):
        return JSONResponse(
            {"error": "Invalid lang, must be one of: en, chs"},
            status_code=400,
        )

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
        payload = await start_chapter_session(
            user_id=user_id,
            souler_id=souler_id,
            chapter_id=chapter_id,
            lang=lang,
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
