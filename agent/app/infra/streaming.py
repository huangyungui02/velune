from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator, Awaitable, Callable
from typing import cast


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
