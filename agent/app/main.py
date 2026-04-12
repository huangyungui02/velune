from __future__ import annotations

from fastapi import FastAPI

from app.chapters_api import router as chapters_router
from app.chat_api import router as chat_router
from app.config import get_settings
from app.echo_api import router as echo_router

settings = get_settings()

app = FastAPI(title=settings.APP_NAME)
app.include_router(chapters_router)
app.include_router(chat_router)
app.include_router(echo_router)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
