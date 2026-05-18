from __future__ import annotations

from fastapi import APIRouter

from app.routes.flow.stream import router as stream_router

router = APIRouter()
router.include_router(stream_router)
