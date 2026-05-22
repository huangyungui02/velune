from __future__ import annotations

from postgrest.types import ReturnMethod

from app.core.config import get_settings
from app.domain import Message, Role

from ._client import await_repo, first_row, get_supabase

settings = get_settings()


async def get_recent_messages(user_id: str, session_id: str) -> list[Message]:
    response = await await_repo(
        get_supabase()
        .table("messages")
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


async def insert_message(
    user_id: str,
    souler_id: str,
    session_id: str,
    role: Role,
    content: str,
    *,
    timeout: float | None = None,
) -> dict[str, str]:
    response = await await_repo(
        get_supabase()
        .table("messages")
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
        .execute(),
        timeout=timeout,
    )

    row = first_row(response.data)
    if not row:
        raise ValueError("Failed to create message")

    return {
        "id": str(row.get("id", "")),
        "created_at": str(row.get("created_at", "")),
    }
