from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException

from app.auth.dependencies import require_lang, require_user_id
from app.core.errors import error_message

from .schemas import FolioMessageRequest
from .services import continue_folio_response, start_folio_response

router = APIRouter()


@router.post("/{lang}/folios/{folio_id}/start")
async def start_folio_route(
    folio_id: UUID,
    normalized_lang: str = Depends(require_lang),
    user_id: str = Depends(require_user_id),
):
    try:
        return await start_folio_response(
            user_id=user_id,
            folio_id=str(folio_id),
            lang=normalized_lang,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=error_message(error)) from error


@router.post("/{lang}/folios/{folio_id}/messages")
async def continue_folio_route(
    folio_id: UUID,
    body: FolioMessageRequest,
    normalized_lang: str = Depends(require_lang),
    user_id: str = Depends(require_user_id),
):
    try:
        return await continue_folio_response(
            user_id=user_id,
            folio_id=str(folio_id),
            session_id=body.session_id,
            content=body.content,
            lang=normalized_lang,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=error_message(error)) from error
