from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.api.dependencies import require_lang, require_user_id
from app.core import Lang
from app.core.errors import error_message
from app.schemas.chat import ChatRequest
from app.services.chat import handle_chat

router = APIRouter()


@router.post("/{lang}/chat")
async def chat(
    body: ChatRequest,
    normalized_lang: Lang = Depends(require_lang),
    user_id: str = Depends(require_user_id),
):
    try:
        return await handle_chat(
            lang=normalized_lang,
            user_id=user_id,
            session_id=body.session_id or "",
            souler_id=body.souler_id or "",
            chapter_id=body.chapter_id or "",
            content=body.cleaned_content,
            reply_length=body.reply_length,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=error_message(error)) from error
