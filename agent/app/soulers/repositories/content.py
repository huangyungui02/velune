from __future__ import annotations

from typing import Any
from app.db.session import fetch_one
from app.core.entities import Souler


def to_souler(raw: Any) -> Souler:
    souler = raw[0] if isinstance(raw, list) and raw else raw
    if not isinstance(souler, dict):
        raise ValueError("Souler not found")

    souler_id = str(souler.get("id", "")).strip()
    name = str(souler.get("name", "")).strip()
    if not souler_id or not name:
        raise ValueError("Souler not found")

    introduction = souler.get("introduction")
    return {
        "id": souler_id,
        "name": name,
        "introduction": str(introduction) if isinstance(introduction, str) else None,
    }


async def get_souler_by_id(souler_id: str, lang: str = "zh") -> Souler:
    row = await fetch_one(
        """
        SELECT s.id, p.name, p.introduction
        FROM public.soulers s
        JOIN public.souler_profile p
            ON p.souler_id = s.id
            AND p.lang = %(lang)s
        WHERE s.id = CAST(%(souler_id)s AS uuid)
        """,
        {"souler_id": souler_id, "lang": lang},
    )
    if not row:
        raise ValueError("Souler not found")
    return to_souler(row)
