from __future__ import annotations

import asyncio
from collections.abc import Awaitable
from datetime import date, datetime
from typing import Any, TypeVar
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine
from supabase import AsyncClient, acreate_client

from app.core.config import get_settings

settings = get_settings()

T = TypeVar("T")

_supabase_auth: AsyncClient | None = None
_engine: AsyncEngine | None = None


async def init_supabase_auth() -> AsyncClient:
    global _supabase_auth
    if _supabase_auth is not None:
        return _supabase_auth

    _supabase_auth = await acreate_client(
        settings.SUPABASE_URL,
        settings.SUPABASE_SERVICE_ROLE_KEY,
    )
    return _supabase_auth


def init_database() -> AsyncEngine:
    global _engine
    if _engine is None:
        _engine = create_async_engine(
            settings.DATABASE_URL,
            pool_pre_ping=True,
            pool_timeout=settings.REPO_TIMEOUT_SECONDS,
        )
    return _engine


async def close_database() -> None:
    global _engine
    if _engine is None:
        return

    await _engine.dispose()
    _engine = None


def get_engine() -> AsyncEngine:
    if _engine is None:
        raise RuntimeError("Database engine not initialized; app lifespan did not run")
    return _engine


def get_supabase_auth() -> AsyncClient:
    if _supabase_auth is None:
        raise RuntimeError("Supabase auth client not initialized; app lifespan did not run")
    return _supabase_auth


def _json_ready(value: Any) -> Any:
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, date | UUID):
        return str(value)
    if isinstance(value, dict):
        return {key: _json_ready(nested) for key, nested in value.items()}
    if isinstance(value, list):
        return [_json_ready(nested) for nested in value]
    return value


def _row_dict(row: Any) -> dict[str, Any]:
    return {key: _json_ready(value) for key, value in dict(row).items()}


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


async def fetch_one(
    sql: str,
    params: dict[str, Any] | None = None,
    *,
    timeout: float | None = None,
) -> dict[str, Any] | None:
    async def run() -> dict[str, Any] | None:
        async with get_engine().connect() as connection:
            result = await connection.execute(text(sql), params or {})
            row = result.mappings().first()
            return _row_dict(row) if row else None

    return await await_repo(run(), timeout=timeout)


async def fetch_all(
    sql: str,
    params: dict[str, Any] | None = None,
    *,
    timeout: float | None = None,
) -> list[dict[str, Any]]:
    async def run() -> list[dict[str, Any]]:
        async with get_engine().connect() as connection:
            result = await connection.execute(text(sql), params or {})
            return [_row_dict(row) for row in result.mappings().all()]

    return await await_repo(run(), timeout=timeout)


async def execute(
    sql: str,
    params: dict[str, Any] | None = None,
    *,
    timeout: float | None = None,
) -> None:
    async def run() -> None:
        async with get_engine().begin() as connection:
            await connection.execute(text(sql), params or {})

    await await_repo(run(), timeout=timeout)


async def execute_fetch_one(
    sql: str,
    params: dict[str, Any] | None = None,
    *,
    timeout: float | None = None,
) -> dict[str, Any] | None:
    async def run() -> dict[str, Any] | None:
        async with get_engine().begin() as connection:
            result = await connection.execute(text(sql), params or {})
            row = result.mappings().first()
            return _row_dict(row) if row else None

    return await await_repo(run(), timeout=timeout)
