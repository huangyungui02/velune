from __future__ import annotations

import logging
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse

from app.api.deps import require_lang, require_user_id
from app.api.http import credit_limit_response
from app.core.lang import Lang
from app.domain.exceptions import CreditLimitError
from app.errors import error_log_payload, error_message
from app.services.chat.chapters import start_chapter_session
from app.services.chat.preferences import normalize_reply_length

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/{lang}/soulers/{souler_id}/chapters/{chapter_id}/start")
async def start_chapter_session_route(
    souler_id: UUID,
    chapter_id: UUID,
    request: Request,
    normalized_lang: Lang = Depends(require_lang),
    user_id: str = Depends(require_user_id),
):
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
            lang=normalized_lang,
            reply_length=reply_length,
        )
        return JSONResponse(payload, status_code=200)
    except CreditLimitError as error:
        return credit_limit_response(error)
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to start chapter session: %s", error_log_payload(error))
        return JSONResponse({"error": error_message(error)}, status_code=400)
