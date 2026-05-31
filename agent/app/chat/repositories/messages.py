from __future__ import annotations

from app.core.config import get_settings
from app.core.entities import Message, Role

from app.db.session import execute_fetch_one, fetch_all

settings = get_settings()


async def get_recent_messages(user_id: str, session_id: str) -> list[Message]:
    rows = await fetch_all(
        """
        SELECT id, user_id, souler_id, session_id, role, content, created_at
        FROM public.messages
        WHERE user_id = CAST(%(user_id)s AS uuid)
          AND session_id = CAST(%(session_id)s AS uuid)
        ORDER BY created_at DESC
        LIMIT %(limit)s
        """,
        {
            "user_id": user_id,
            "session_id": session_id,
            "limit": settings.CHAT_HISTORY_LIMIT,
        },
    )

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
    row = await execute_fetch_one(
        """
        INSERT INTO public.messages (user_id, souler_id, session_id, role, content)
        VALUES (
            CAST(%(user_id)s AS uuid),
            CAST(%(souler_id)s AS uuid),
            CAST(%(session_id)s AS uuid),
            %(role)s,
            %(content)s
        )
        RETURNING id, created_at
        """,
        {
            "user_id": user_id,
            "souler_id": souler_id,
            "session_id": session_id,
            "role": role,
            "content": content,
        },
        timeout=timeout,
    )

    if not row:
        raise ValueError("Failed to create message")

    return {
        "id": str(row.get("id", "")),
        "created_at": str(row.get("created_at", "")),
    }
