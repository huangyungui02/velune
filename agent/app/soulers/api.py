from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.auth.dependencies import require_lang, require_user_id
from app.core.common import Lang
from app.soulers.services.resolution import get_resolution_status
from app.soulers.services.resolution import resolve_or_enqueue_souler

router = APIRouter()


class SoulerResolveRequest(BaseModel):
    name: str = Field(min_length=1, max_length=128)


@router.post("/{lang}/soulers/resolve")
async def resolve_souler(
    request: SoulerResolveRequest,
    normalized_lang: Lang = Depends(require_lang),
    _user_id: str = Depends(require_user_id),
):
    return await resolve_or_enqueue_souler(request.name, normalized_lang)


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
