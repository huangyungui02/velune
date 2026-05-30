from fastapi import APIRouter

from app.api.v1.endpoints import chapters, chat, soulers, starsea

router = APIRouter()
router.include_router(starsea.router)
router.include_router(chat.router)
router.include_router(soulers.router)
router.include_router(chapters.router)
