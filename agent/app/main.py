from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.router import router
from app.core.config import get_settings
from app.db.session import close_database, open_database
from app.auth.client import init_supabase_auth
from app.seastar.checkpoint import close_starsea_checkpoint, init_starsea_checkpoint
from app.seastar.graph import reset_graph
from app.tasks import broker

settings = get_settings()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    await open_database()
    await init_starsea_checkpoint()
    await init_supabase_auth()
    if not broker.is_worker_process:
        await broker.startup()
    try:
        yield
    finally:
        if not broker.is_worker_process:
            await broker.shutdown()
        reset_graph()
        await close_starsea_checkpoint()
        await close_database()


app = FastAPI(title=settings.APP_NAME, lifespan=lifespan)
app.include_router(router)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
