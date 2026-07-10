from __future__ import annotations

from typing import TypedDict

from app.db.session import fetch_one


class Folio(TypedDict):
    id: str
    souler_id: str
    title: str
    prompt: str


async def get_public_folio(folio_id: str, lang: str) -> Folio:
    row = await fetch_one(
        """
        SELECT
            f.id,
            f.souler_id,
            ft.title,
            fp.content AS prompt
        FROM public.folios AS f
        JOIN public.folio_translations AS ft
            ON ft.folio_id = f.id
            AND ft.lang = %(lang)s
        JOIN public.folio_prompts AS fp
            ON fp.folio_id = f.id
            AND fp.is_active = TRUE
        WHERE f.id = CAST(%(folio_id)s AS uuid)
          AND f.is_public = TRUE
        """,
        {"folio_id": folio_id, "lang": lang},
    )
    if not row:
        raise ValueError("Folio not found")

    return {
        "id": str(row["id"]),
        "souler_id": str(row["souler_id"]),
        "title": str(row["title"]),
        "prompt": str(row["prompt"]),
    }
