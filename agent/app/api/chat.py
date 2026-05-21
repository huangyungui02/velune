from __future__ import annotations

from fastapi import APIRouter, Depends, Request

from app.api.deps import require_lang, require_user_id
from app.core.lang import Lang
from app.services.chat import handle_chat

router = APIRouter()


@router.post("/{lang}/chat")
async def chat(
    request: Request,
    normalized_lang: Lang = Depends(require_lang),
    user_id: str = Depends(require_user_id),
):
    return await handle_chat(normalized_lang, user_id, request)
