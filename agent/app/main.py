from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.routes import router
from app.core.config import get_settings
from app.repositories._client import init_supabase

settings = get_settings()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    await init_supabase()
    yield


app = FastAPI(title=settings.APP_NAME, lifespan=lifespan)
app.include_router(router)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
