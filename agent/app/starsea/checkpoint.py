from __future__ import annotations

from contextlib import AbstractAsyncContextManager, AsyncExitStack

from langgraph.checkpoint.redis.ashallow import AsyncShallowRedisSaver

from app.core.config import get_settings


class StarseaCheckpointManager:
    def __init__(self) -> None:
        self._stack: AsyncExitStack | None = None
        self._checkpointer: AsyncShallowRedisSaver | None = None

    async def startup(self) -> AsyncShallowRedisSaver:
        if self._checkpointer is None:
            stack = AsyncExitStack()
            try:
                checkpointer = await stack.enter_async_context(self._create_checkpointer())
                await checkpointer.asetup()
            except Exception:
                await stack.aclose()
                raise

            self._stack = stack
            self._checkpointer = checkpointer
        return self._checkpointer

    def get(self) -> AsyncShallowRedisSaver:
        if self._checkpointer is None:
            raise RuntimeError("Starsea checkpoint not initialized; app lifespan did not run")
        return self._checkpointer

    async def close(self) -> None:
        try:
            if self._stack is not None:
                await self._stack.aclose()
        finally:
            self.reset()

    def reset(self) -> None:
        self._checkpointer = None
        self._stack = None

    def _create_checkpointer(self) -> AbstractAsyncContextManager[AsyncShallowRedisSaver]:
        settings = get_settings()
        return (
            AsyncShallowRedisSaver.from_conn_string(
                settings.REDIS_URL,
                ttl={
                    "default_ttl": settings.LANGGRAPH_CHECKPOINT_TTL_MINUTES,
                    "refresh_on_read": True,
                },
                checkpoint_prefix="velune:starsea:checkpoint",
                checkpoint_write_prefix="velune:starsea:checkpoint_write",
            )
        )


checkpoint_manager = StarseaCheckpointManager()
