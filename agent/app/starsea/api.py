from __future__ import annotations

import logging

from fastapi import APIRouter, Depends

from app.auth.billing import is_user_premium
from app.auth.dependencies import require_lang, require_user_id
from app.core.errors import error_log_data, error_message
from app.core.sse import sse_response
from app.starsea.schemas.starsea import StarseaRequest
from app.starsea import emit_starsea_error, start_starsea_stream

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/{lang}/starsea")
async def starsea(
    body: StarseaRequest,
    normalized_lang: str = Depends(require_lang),
    user_id: str = Depends(require_user_id),
):
    try:
        return sse_response(
            start_starsea_stream(
                content=body.content,
                metadata=body.runtime_metadata,
                thread_id=body.thread_id,
                user_id=user_id,
                is_premium=await is_user_premium(user_id),
                lang=normalized_lang,
            )
        )
    except Exception as error:  # noqa: BLE001
        logger.error("Failed before starsea stream start: %s", error_log_data(error))
        return sse_response(emit_starsea_error(error_message(error)))
