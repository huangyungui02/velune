from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.routes import router
from app.core.config import get_settings
from app.repositories._client import close_database, init_database, init_supabase_auth

settings = get_settings()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    init_database()
    await init_supabase_auth()
    try:
        yield
    finally:
        await close_database()


app = FastAPI(title=settings.APP_NAME, lifespan=lifespan)
app.include_router(router)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
