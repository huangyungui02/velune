from __future__ import annotations

from typing import Any
from app.db.session import fetch_one
from app.core.entities import Chapter


def to_chapter(raw: Any) -> Chapter:
    chapter = raw[0] if isinstance(raw, list) and raw else raw
    if not isinstance(chapter, dict):
        raise ValueError("Chapter not found")

    chapter_id = str(chapter.get("id", "")).strip()
    souler_id = str(chapter.get("souler_id", "")).strip()
    if not chapter_id or not souler_id:
        raise ValueError("Chapter not found")

    seq_value = chapter.get("seq")
    if not isinstance(seq_value, int) or seq_value <= 0:
        raise ValueError("Chapter not found")

    return {
        "id": chapter_id,
        "souler_id": souler_id,
        "seq": seq_value,
        "title": str(chapter.get("title", "")).strip(),
        "subtitle": str(chapter.get("subtitle", "")).strip(),
        "task": str(chapter.get("task", "")).strip(),
    }


async def get_chapter_by_id(chapter_id: str, lang: str = "zh") -> Chapter:
    row = await fetch_one(
        """
        SELECT id, souler_id, seq, title, subtitle, task
        FROM public.chapters
        WHERE id = CAST(%(chapter_id)s AS uuid)
            AND lang = %(lang)s
        """,
        {"chapter_id": chapter_id, "lang": lang},
    )
    if not row:
        raise ValueError("Chapter not found")
    return to_chapter(row)
