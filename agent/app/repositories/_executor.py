from __future__ import annotations

import asyncio
from collections.abc import Callable
from typing import TypeVar

from starlette.concurrency import run_in_threadpool

from app.config import get_settings

settings = get_settings()

T = TypeVar("T")


async def run_sync(
    func: Callable[..., T],
    /,
    *args: object,
    timeout: float | None = None,
) -> T:
    try:
        return await asyncio.wait_for(
            run_in_threadpool(func, *args),
            timeout=timeout or settings.REPO_TIMEOUT_SECONDS,
        )
    except asyncio.TimeoutError as error:
        raise TimeoutError(f"{func.__name__} timed out") from error
