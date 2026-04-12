from __future__ import annotations

from typing import Any

from .types import ChapterContext, Souler


def to_souler(raw: Any) -> Souler:
    souler = raw[0] if isinstance(raw, list) and raw else raw
    if not isinstance(souler, dict):
        raise ValueError("Souler not found")

    souler_id = str(souler.get("id", "")).strip()
    name = str(souler.get("name", "")).strip()
    if not souler_id or not name:
        raise ValueError("Souler not found")

    bio = souler.get("bio")
    return {
        "id": souler_id,
        "name": name,
        "bio": str(bio) if isinstance(bio, str) else None,
    }


def to_chapter(raw: Any) -> ChapterContext:
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
        "role": str(chapter.get("role", "")).strip(),
        "task": str(chapter.get("task", "")).strip(),
    }
