from __future__ import annotations

from ._client import first_row, supabase
from .types import MessageRow, Role


def get_recent_messages(user_id: str, session_id: str) -> list[MessageRow]:
    response = (
        supabase.table("messages")
        .select("id, user_id, souler_id, session_id, role, content, created_at")
        .eq("user_id", user_id)
        .eq("session_id", session_id)
        .order("created_at", desc=True)
        .limit(20)
        .execute()
    )

    rows = response.data if isinstance(response.data, list) else []
    rows.reverse()
    return rows  # type: ignore[return-value]


def insert_message(
    user_id: str,
    souler_id: str,
    session_id: str,
    role: Role,
    content: str,
) -> dict[str, str]:
    response = (
        supabase.table("messages")
        .insert(
            {
                "user_id": user_id,
                "souler_id": souler_id,
                "session_id": session_id,
                "role": role,
                "content": content,
            },
            returning="representation",
        )
        .execute()
    )

    row = first_row(response.data)
    if not row:
        raise ValueError("Failed to create message")

    return {
        "id": str(row.get("id", "")),
        "created_at": str(row.get("created_at", "")),
    }


def insert_session_message(
    user_id: str,
    souler_id: str,
    session_id: str,
    role: Role,
    content: str,
) -> None:
    (
        supabase.table("messages")
        .insert(
            {
                "user_id": user_id,
                "souler_id": souler_id,
                "session_id": session_id,
                "role": role,
                "content": content,
            }
        )
        .execute()
    )
