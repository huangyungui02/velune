from __future__ import annotations

import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException

from app.api.dependencies import require_lang, require_user_id
from app.core.errors import error_log_payload, error_message
from app.schemas.chapters import ChapterStartRequest
from app.schemas.common import Lang
from app.services.chat.chapters import start_chapter_session
from app.services.chat.preferences import DEFAULT_REPLY_LENGTH

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/{lang}/soulers/{souler_id}/chapters/{chapter_id}/start")
async def start_chapter_session_route(
    souler_id: UUID,
    chapter_id: UUID,
    body: ChapterStartRequest | None = None,
    normalized_lang: Lang = Depends(require_lang),
    user_id: str = Depends(require_user_id),
):
    try:
        payload = await start_chapter_session(
            user_id=user_id,
            souler_id=souler_id,
            chapter_id=chapter_id,
            lang=normalized_lang,
            reply_length=body.reply_length if body else DEFAULT_REPLY_LENGTH,
        )
        return payload
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to start chapter session: %s", error_log_payload(error))
        raise HTTPException(status_code=400, detail=error_message(error)) from error
