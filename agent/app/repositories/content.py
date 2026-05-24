from __future__ import annotations

from app.domain import Chapter, Souler

from .database import fetch_one
from .parsers import to_chapter, to_souler


async def get_souler_by_id(souler_id: str) -> Souler:
    row = await fetch_one(
        """
        SELECT id, name, bio
        FROM public.soulers
        WHERE id = CAST(%(souler_id)s AS uuid)
        """,
        {"souler_id": souler_id},
    )
    if not row:
        raise ValueError("Souler not found")
    return to_souler(row)


async def get_chapter_by_id(chapter_id: str) -> Chapter:
    row = await fetch_one(
        """
        SELECT id, souler_id, seq, title, subtitle, role, task
        FROM public.chapters
        WHERE id = CAST(%(chapter_id)s AS uuid)
        """,
        {"chapter_id": chapter_id},
    )
    if not row:
        raise ValueError("Chapter not found")
    return to_chapter(row)
