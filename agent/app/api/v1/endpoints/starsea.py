from __future__ import annotations

import logging
from uuid import uuid4

from fastapi import APIRouter, Depends

from app.api.dependencies import require_lang, require_user_id
from app.core import Lang
from app.core.errors import error_log_payload, error_message
from app.core.sse import sse_response
from app.schemas.starsea import StarseaRequest, StarseaResumeRequest
from app.services.starsea import emit_starsea_error, resume_starsea_stream, start_starsea_stream

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/{lang}/starsea")
async def starsea(
    body: StarseaRequest,
    normalized_lang: Lang = Depends(require_lang),
    user_id: str = Depends(require_user_id),
):
    try:
        thread_id = body.thread_id or str(uuid4())
        return sse_response(
            start_starsea_stream(
                content=body.cleaned_content,
                metadata=body.safe_metadata,
                thread_id=thread_id,
                user_id=user_id,
                intent=body.intent,
                lang=normalized_lang,
            )
        )
    except Exception as error:  # noqa: BLE001
        logger.error("Failed before starsea stream start: %s", error_log_payload(error))
        return sse_response(emit_starsea_error(error_message(error)))


@router.post("/{lang}/starsea/resume")
async def starsea_resume(
    body: StarseaResumeRequest,
    normalized_lang: Lang = Depends(require_lang),
    user_id: str = Depends(require_user_id),
):
    try:
        return sse_response(
            resume_starsea_stream(
                thread_id=body.thread_id,
                user_id=user_id,
                approved=body.approved,
                content=body.cleaned_content,
                lang=normalized_lang,
            )
        )
    except Exception as error:  # noqa: BLE001
        logger.error("Failed before starsea resume stream start: %s", error_log_payload(error))
        return sse_response(emit_starsea_error(error_message(error)))
