from __future__ import annotations

from ._client import supabase


def create_or_update_resonance(
    user_id: str,
    souler_id: str,
    last_session_id: str | None,
) -> None:
    row: dict[str, str] = {
        "user_id": user_id,
        "souler_id": souler_id,
    }
    if last_session_id is not None:
        row["last_session_id"] = last_session_id

    supabase.table("resonances").upsert(
        row,
        on_conflict="user_id,souler_id",
    ).execute()
