from __future__ import annotations

from postgrest.types import ReturnMethod

from app.config import get_settings
from app.domain.types import Message, Role

from ._client import first_row, supabase

settings = get_settings()


def get_recent_messages(user_id: str, session_id: str) -> list[Message]:
    response = (
        supabase.table("messages")
        .select("id, user_id, souler_id, session_id, role, content, created_at")
        .eq("user_id", user_id)
        .eq("session_id", session_id)
        .order("created_at", desc=True)
        .limit(settings.CHAT_HISTORY_LIMIT)
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
            returning=ReturnMethod.representation,
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
