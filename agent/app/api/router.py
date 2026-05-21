from __future__ import annotations

from fastapi import APIRouter

from app.api import chapters, chat, soulers

router = APIRouter()
router.include_router(chat.router)
router.include_router(chapters.router)
router.include_router(soulers.router)
