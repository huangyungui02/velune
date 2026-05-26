from __future__ import annotations

from typing import Any, TypedDict

from psycopg.types.json import Jsonb

from .database import execute_fetch_one, fetch_one, get_pool


class Glimmer(TypedDict):
    id: str
    user_id: str
    content: str
    created_at: str
    status: str


class GlimmerMessageDraft(TypedDict):
    type: str
    role: str | None
    content: str | None
    payload: dict[str, Any]


async def get_glimmer_by_id(user_id: str, glimmer_id: str) -> Glimmer | None:
    row = await fetch_one(
        """
        SELECT id, user_id, content, created_at, status
        FROM public.glimmers
        WHERE id = CAST(%(glimmer_id)s AS uuid)
          AND user_id = CAST(%(user_id)s AS uuid)
        """,
        {"user_id": user_id, "glimmer_id": glimmer_id},
    )
    if not row:
        return None

    return {
        "id": str(row.get("id", "")),
        "user_id": str(row.get("user_id", "")),
        "content": str(row.get("content", "")),
        "created_at": str(row.get("created_at", "")),
        "status": str(row.get("status", "")),
    }


async def create_glimmer(
    user_id: str,
    content: str,
    *,
    status: str = "complete",
) -> Glimmer:
    row = await execute_fetch_one(
        """
        INSERT INTO public.glimmers (user_id, content, status)
        VALUES (CAST(%(user_id)s AS uuid), %(content)s, %(status)s::glimmer_status)
        RETURNING id, user_id, content, created_at, status
        """,
        {"user_id": user_id, "content": content, "status": status},
    )
    if not row:
        raise RuntimeError("Failed to create glimmer")

    return {
        "id": str(row.get("id", "")),
        "user_id": str(row.get("user_id", "")),
        "content": str(row.get("content", "")),
        "created_at": str(row.get("created_at", "")),
        "status": str(row.get("status", "")),
    }


async def create_glimmer_with_messages(
    user_id: str,
    content: str,
    messages: list[GlimmerMessageDraft],
    *,
    status: str = "complete",
) -> Glimmer:
    if not messages:
        raise ValueError("Glimmer archive messages cannot be empty")

    async with get_pool().connection() as connection:
        async with connection.transaction():
            async with connection.cursor() as cursor:
                await cursor.execute(
                    """
                    INSERT INTO public.glimmers (user_id, content, status)
                    VALUES (CAST(%(user_id)s AS uuid), %(content)s, %(status)s::glimmer_status)
                    RETURNING id, user_id, content, created_at, status
                    """,
                    {"user_id": user_id, "content": content, "status": status},
                )
                row = await cursor.fetchone()
                if not row:
                    raise RuntimeError("Failed to create glimmer")

                glimmer_id = str(row["id"])
                await cursor.executemany(
                    """
                    INSERT INTO public.glimmer_messages (
                        user_id,
                        glimmer_id,
                        sequence,
                        type,
                        role,
                        content,
                        payload
                    )
                    VALUES (
                        CAST(%(user_id)s AS uuid),
                        CAST(%(glimmer_id)s AS uuid),
                        %(sequence)s,
                        %(type)s,
                        %(role)s,
                        %(content)s,
                        %(payload)s
                    )
                    """,
                    [
                        {
                            "user_id": user_id,
                            "glimmer_id": glimmer_id,
                            "sequence": index,
                            "type": message["type"],
                            "role": message.get("role"),
                            "content": message.get("content"),
                            "payload": Jsonb(message.get("payload") or {}),
                        }
                        for index, message in enumerate(messages)
                    ],
                )

    return {
        "id": str(row.get("id", "")),
        "user_id": str(row.get("user_id", "")),
        "content": str(row.get("content", "")),
        "created_at": str(row.get("created_at", "")),
        "status": str(row.get("status", "")),
    }
