from __future__ import annotations

from contextlib import AbstractAsyncContextManager

from langgraph.checkpoint.redis.aio import AsyncRedisSaver

from app.core.config import get_settings


_checkpointer_context: AbstractAsyncContextManager[AsyncRedisSaver] | None = None
_checkpointer: AsyncRedisSaver | None = None


async def init_starsea_checkpoint() -> AsyncRedisSaver:
    global _checkpointer, _checkpointer_context
    if _checkpointer is None:
        settings = get_settings()
        _checkpointer_context = AsyncRedisSaver.from_conn_string(
            settings.REDIS_URL,
            ttl={
                "default_ttl": settings.LANGGRAPH_CHECKPOINT_TTL_MINUTES,
                "refresh_on_read": True,
            },
            checkpoint_prefix="velune:starsea:checkpoint",
            checkpoint_write_prefix="velune:starsea:checkpoint_write",
        )
        _checkpointer = await _checkpointer_context.__aenter__()
    return _checkpointer


def get_starsea_checkpointer() -> AsyncRedisSaver:
    if _checkpointer is None:
        raise RuntimeError("Starsea checkpoint not initialized; app lifespan did not run")
    return _checkpointer


async def close_starsea_checkpoint() -> None:
    global _checkpointer, _checkpointer_context
    if _checkpointer_context is not None:
        await _checkpointer_context.__aexit__(None, None, None)
    _checkpointer = None
    _checkpointer_context = None


def reset_starsea_checkpoint() -> None:
    global _checkpointer, _checkpointer_context
    _checkpointer = None
    _checkpointer_context = None
