from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.router import router
from app.core.config import get_settings
from app.db.session import database_manager
from app.auth.client import supabase_auth_manager
from app.starsea.checkpoint import checkpoint_manager
from app.starsea.graph import reset_graph
from app.tasks import broker

settings = get_settings()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    await database_manager.open()
    await checkpoint_manager.startup()
    await supabase_auth_manager.startup()
    if not broker.is_worker_process:
        await broker.startup()
    try:
        yield
    finally:
        if not broker.is_worker_process:
            await broker.shutdown()
        reset_graph()
        await checkpoint_manager.close()
        await database_manager.close()


app = FastAPI(title=settings.APP_NAME, lifespan=lifespan)
app.include_router(router)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
