from __future__ import annotations

from fastapi import FastAPI

from app.routes.chat import router as chat_router
from app.config import get_settings
from app.routes.echo import router as echo_router

settings = get_settings()

app = FastAPI(title=settings.APP_NAME)
app.include_router(chat_router)
app.include_router(echo_router)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
