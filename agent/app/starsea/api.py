from __future__ import annotations

from fastapi import APIRouter, Depends

from app.auth.dependencies import require_lang, require_user_id
from app.core.sse import sse_response
from app.starsea import start_starsea_stream
from app.starsea.schemas.starsea import StarseaRequest

router = APIRouter()


@router.post("/{lang}/starsea")
def starsea(
    body: StarseaRequest,
    normalized_lang: str = Depends(require_lang),
    user_id: str = Depends(require_user_id),
):
    return sse_response(
        start_starsea_stream(
            content=body.content,
            metadata=body.runtime_metadata,
            thread_id=body.thread_id,
            user_id=user_id,
            lang=normalized_lang,
        )
    )
