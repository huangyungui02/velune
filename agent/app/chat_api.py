from __future__ import annotations

from fastapi import APIRouter, Request

from app.echo_logic import Lang
from app.services.chat import handle_chat

router = APIRouter()


@router.post("/{lang}/chat")
async def chat(lang: Lang, request: Request):
    return await handle_chat(lang, request)
