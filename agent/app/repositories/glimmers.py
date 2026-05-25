from __future__ import annotations

from typing import TypedDict

from .database import execute_fetch_one, fetch_one


class Glimmer(TypedDict):
    id: str
    user_id: str
    content: str
    created_at: str
    status: str


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
