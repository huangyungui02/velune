from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.routes import router
from app.core.config import get_settings
from app.repositories.auth_client import init_supabase_auth
from app.repositories.database import close_database, open_database
from app.services.starsea.checkpoint import init_starsea_checkpoint, reset_starsea_checkpoint
from app.services.starsea.graph import reset_graph

settings = get_settings()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    await open_database()
    await init_starsea_checkpoint()
    await init_supabase_auth()
    try:
        yield
    finally:
        reset_graph()
        reset_starsea_checkpoint()
        await close_database()


app = FastAPI(title=settings.APP_NAME, lifespan=lifespan)
app.include_router(router)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
