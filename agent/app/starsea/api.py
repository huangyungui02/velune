from __future__ import annotations

import logging
from uuid import uuid4

from fastapi import APIRouter, Depends

from app.auth.dependencies import require_lang, require_user_id
from app.core.errors import error_log_payload, error_message
from app.core.sse import sse_response
from app.core.common import Lang
from app.starsea.schemas.starsea import StarseaRequest
from app.starsea import emit_starsea_error, start_starsea_stream

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
