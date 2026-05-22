from __future__ import annotations

from app.domain import Chapter, Souler

from ._client import await_repo, first_row, get_supabase
from .parsers import to_chapter, to_souler


async def get_souler_by_id(souler_id: str) -> Souler:
    response = await await_repo(
        get_supabase()
        .table("soulers")
        .select("id, name, bio")
        .eq("id", souler_id)
        .single()
        .execute()
    )
    row = first_row(response.data)
    if not row:
        raise ValueError("Souler not found")
    return to_souler(row)


async def get_chapter_by_id(chapter_id: str) -> Chapter:
    response = await await_repo(
        get_supabase()
        .table("chapters")
        .select("id, souler_id, seq, title, subtitle, role, task")
        .eq("id", chapter_id)
        .single()
        .execute()
    )
    row = first_row(response.data)
    if not row:
        raise ValueError("Chapter not found")
    return to_chapter(row)
