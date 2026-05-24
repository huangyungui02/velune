from __future__ import annotations

from langgraph.checkpoint.postgres.aio import AsyncPostgresSaver

from app.repositories.database import get_pool

_checkpointer: AsyncPostgresSaver | None = None


async def init_starsea_checkpoint() -> AsyncPostgresSaver:
    global _checkpointer
    if _checkpointer is None:
        _checkpointer = AsyncPostgresSaver(get_pool())
        await _checkpointer.setup()
    return _checkpointer


def get_starsea_checkpointer() -> AsyncPostgresSaver:
    if _checkpointer is None:
        raise RuntimeError("Starsea checkpoint not initialized; app lifespan did not run")
    return _checkpointer


def reset_starsea_checkpoint() -> None:
    global _checkpointer
    _checkpointer = None
