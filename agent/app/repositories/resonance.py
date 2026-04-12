from __future__ import annotations

from ._client import supabase


def create_or_update_resonance(
    user_id: str,
    souler_id: str,
    last_session_id: str | None,
    last_session_title: str,
) -> None:
    supabase.rpc(
        "touch_resonance",
        {
            "p_user_id": user_id,
            "p_souler_id": souler_id,
            "p_last_session_id": last_session_id,
            "p_last_session_title": last_session_title,
        },
    ).execute()
