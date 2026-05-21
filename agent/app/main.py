from __future__ import annotations

from fastapi import FastAPI

from app.routes.chat import router as chat_router
from app.config import get_settings

settings = get_settings()

app = FastAPI(title=settings.APP_NAME)
app.include_router(chat_router)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
