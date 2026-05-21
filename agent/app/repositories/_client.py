from __future__ import annotations

import asyncio
from collections.abc import Awaitable
from typing import Any, TypeVar

from supabase import AsyncClient, acreate_client
from supabase.lib.client_options import AsyncClientOptions

from app.config import get_settings

settings = get_settings()

T = TypeVar("T")

_supabase: AsyncClient | None = None


async def init_supabase() -> AsyncClient:
    global _supabase
    if _supabase is not None:
        return _supabase

    options = AsyncClientOptions(
        postgrest_client_timeout=settings.REPO_TIMEOUT_SECONDS,
    )
    _supabase = await acreate_client(
        settings.SUPABASE_URL,
        settings.SUPABASE_SERVICE_ROLE_KEY,
        options,
    )
    return _supabase


def get_supabase() -> AsyncClient:
    if _supabase is None:
        raise RuntimeError("Supabase client not initialized; app lifespan did not run")
    return _supabase


async def await_repo(
    awaitable: Awaitable[T],
    *,
    timeout: float | None = None,
) -> T:
    try:
        return await asyncio.wait_for(
            awaitable,
            timeout=timeout or settings.REPO_TIMEOUT_SECONDS,
        )
    except asyncio.TimeoutError as error:
        raise TimeoutError("Repository request timed out") from error


def first_row(data: Any) -> dict[str, Any] | None:
    if isinstance(data, list):
        return data[0] if data else None
    if isinstance(data, dict):
        return data
    return None
