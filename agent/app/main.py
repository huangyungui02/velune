from __future__ import annotations

from fastapi import FastAPI

from app.api.router import router
from app.config import get_settings

settings = get_settings()

app = FastAPI(title=settings.APP_NAME)
app.include_router(router)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
