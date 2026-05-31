from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException

from app.auth.dependencies import require_lang, require_user_id
from app.core.common import Lang
from app.soulers.services.resolution import get_resolution_status

router = APIRouter()


@router.get("/{lang}/soulers/resolutions/{request_id}")
async def souler_resolution_status(
    request_id: UUID,
    _normalized_lang: Lang = Depends(require_lang),
    _user_id: str = Depends(require_user_id),
):
    payload = await get_resolution_status(str(request_id))
    if payload is None:
        raise HTTPException(status_code=404, detail="Resolution request not found")
    return payload
