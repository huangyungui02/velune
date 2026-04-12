from __future__ import annotations

from ._client import first_row, supabase
from .parsers import to_chapter, to_souler
from .types import ChapterContext, Souler


def get_souler_by_id(souler_id: str) -> Souler:
    response = (
        supabase.table("soulers")
        .select("id, name, bio")
        .eq("id", souler_id)
        .single()
        .execute()
    )
    row = first_row(response.data)
    if not row:
        raise ValueError("Souler not found")
    return to_souler(row)


def get_chapter_by_id(chapter_id: str) -> ChapterContext:
    response = (
        supabase.table("chapters")
        .select("id, souler_id, seq, title, subtitle, role, task")
        .eq("id", chapter_id)
        .single()
        .execute()
    )
    row = first_row(response.data)
    if not row:
        raise ValueError("Chapter not found")
    return to_chapter(row)
