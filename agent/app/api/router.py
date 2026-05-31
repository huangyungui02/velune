from fastapi import APIRouter

from app.seastar.api import router as seastar_router
from app.chat.api import router as chat_router
from app.soulers.api import router as soulers_router

router = APIRouter()

v1_router = APIRouter()
v1_router.include_router(seastar_router)
v1_router.include_router(chat_router)
v1_router.include_router(soulers_router)

router.include_router(v1_router, prefix="/api/v1")
