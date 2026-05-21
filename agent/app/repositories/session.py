from __future__ import annotations

from datetime import datetime, timezone

from postgrest.types import ReturnMethod

from app.domain.types import Session

from ._client import await_repo, first_row, get_supabase
from .parsers import to_chapter, to_souler


async def get_session_by_id(user_id: str, session_id: str) -> Session:
    response = await await_repo(
        get_supabase()
        .table("sessions")
        .select(
            "id, user_id, souler_id, title, chapter_id, "
            "soulers(id, name, bio), "
            "chapters(id, souler_id, seq, title, subtitle, role, task)"
        )
        .eq("id", session_id)
        .eq("user_id", user_id)
        .single()
        .execute()
    )

    row = first_row(response.data)
    if not row:
        raise ValueError("Session not found")

    chapter = row.get("chapters")
    parsed_chapter = to_chapter(chapter) if chapter else None
    return {
        "id": str(row.get("id")),
        "souler_id": str(row.get("souler_id")),
        "title": str(row.get("title", "")),
        "souler": to_souler(row.get("soulers")),
        "chapter": parsed_chapter,
    }


async def create_session(
    user_id: str,
    souler_id: str,
    title: str = "",
    chapter_id: str | None = None,
) -> str:
    response = await await_repo(
        get_supabase()
        .table("sessions")
        .insert(
            {
                "user_id": user_id,
                "souler_id": souler_id,
                "title": title,
                "chapter_id": chapter_id,
            },
            returning=ReturnMethod.representation,
        )
        .execute()
    )
    row = first_row(response.data)
    if not row or not row.get("id"):
        raise ValueError("Failed to create session")
    return str(row["id"])


async def delete_session(user_id: str, session_id: str) -> None:
    await await_repo(
        get_supabase()
        .table("sessions")
        .delete()
        .eq("id", session_id)
        .eq("user_id", user_id)
        .execute()
    )


async def update_session_title(
    user_id: str,
    session_id: str,
    title: str,
    *,
    timeout: float | None = None,
) -> None:
    await await_repo(
        get_supabase()
        .table("sessions")
        .update({"title": title})
        .eq("id", session_id)
        .eq("user_id", user_id)
        .execute(),
        timeout=timeout,
    )


async def touch_session(
    user_id: str,
    session_id: str,
    *,
    timeout: float | None = None,
) -> None:
    await await_repo(
        get_supabase()
        .table("sessions")
        .update({"updated_at": datetime.now(timezone.utc).isoformat()})
        .eq("id", session_id)
        .eq("user_id", user_id)
        .execute(),
        timeout=timeout,
    )
