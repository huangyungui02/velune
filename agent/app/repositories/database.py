from __future__ import annotations

import asyncio
from collections.abc import Awaitable
from datetime import date, datetime
from typing import Any, TypeVar
from uuid import UUID

from psycopg.rows import dict_row
from psycopg_pool import AsyncConnectionPool

from app.core.config import get_settings

settings = get_settings()

T = TypeVar("T")

_pool: AsyncConnectionPool | None = None


def init_database() -> AsyncConnectionPool:
    global _pool
    if _pool is None:
        _pool = AsyncConnectionPool(
            settings.DATABASE_URL,
            kwargs={
                "autocommit": True,
                "row_factory": dict_row,
            },
            max_size=4,
            timeout=settings.REPO_TIMEOUT_SECONDS,
            open=False,
        )
    return _pool


async def close_database() -> None:
    global _pool
    if _pool is None:
        return

    await _pool.close()
    _pool = None


async def open_database() -> AsyncConnectionPool:
    pool = init_database()
    await pool.open(wait=True)
    return pool


def get_pool() -> AsyncConnectionPool:
    if _pool is None:
        raise RuntimeError("Database pool not initialized; app lifespan did not run")
    return _pool


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
        async with get_pool().connection() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute(sql, params or {})
                row = await cursor.fetchone()
            return _row_dict(row) if row else None

    return await await_repo(run(), timeout=timeout)


async def fetch_all(
    sql: str,
    params: dict[str, Any] | None = None,
    *,
    timeout: float | None = None,
) -> list[dict[str, Any]]:
    async def run() -> list[dict[str, Any]]:
        async with get_pool().connection() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute(sql, params or {})
                rows = await cursor.fetchall()
            return [_row_dict(row) for row in rows]

    return await await_repo(run(), timeout=timeout)


async def execute(
    sql: str,
    params: dict[str, Any] | None = None,
    *,
    timeout: float | None = None,
) -> None:
    async def run() -> None:
        async with get_pool().connection() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute(sql, params or {})

    await await_repo(run(), timeout=timeout)


async def execute_fetch_one(
    sql: str,
    params: dict[str, Any] | None = None,
    *,
    timeout: float | None = None,
) -> dict[str, Any] | None:
    async def run() -> dict[str, Any] | None:
        async with get_pool().connection() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute(sql, params or {})
                row = await cursor.fetchone()
            return _row_dict(row) if row else None

    return await await_repo(run(), timeout=timeout)
