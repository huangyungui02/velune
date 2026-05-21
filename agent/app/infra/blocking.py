from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator, Callable
from typing import Awaitable, TypeVar, cast

from app.config import get_settings

settings = get_settings()

T = TypeVar("T")


async def run_blocking(
    label: str,
    func: Callable[..., T],
    *args: object,
    timeout: float | None = None,
) -> T:
    try:
        return await asyncio.wait_for(
            asyncio.to_thread(func, *args),
            timeout=timeout or settings.REPO_TIMEOUT_SECONDS,
        )
    except asyncio.TimeoutError as error:
        raise TimeoutError(f"{label} timed out") from error


async def stream_with_timeout(
    chunks: AsyncIterator[str],
    *,
    first_chunk_timeout: float,
    idle_timeout: float,
) -> AsyncIterator[str]:
    iterator = chunks.__aiter__()
    next_timeout = first_chunk_timeout
    try:
        while True:
            try:
                chunk = await asyncio.wait_for(iterator.__anext__(), timeout=next_timeout)
            except StopAsyncIteration:
                return
            except asyncio.TimeoutError as error:
                raise TimeoutError("Model response timed out") from error

            next_timeout = idle_timeout
            yield chunk
    finally:
        aclose = getattr(iterator, "aclose", None)
        if callable(aclose):
            await cast(Callable[[], Awaitable[None]], aclose)()
