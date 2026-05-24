from __future__ import annotations

from typing import TypedDict

from .database import fetch_one


class Glimmer(TypedDict):
    id: str
    user_id: str
    content: str


async def get_glimmer_by_id(user_id: str, glimmer_id: str) -> Glimmer | None:
    row = await fetch_one(
        """
        SELECT id, user_id, content
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
    }
