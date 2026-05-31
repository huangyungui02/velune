from __future__ import annotations

from datetime import datetime, timezone

from app.core.entities import Session

from app.db.session import execute, execute_fetch_one, fetch_one
from app.chat.repositories.chapters import to_chapter
from app.soulers.repositories.content import to_souler


async def get_session_by_id(user_id: str, session_id: str) -> Session:
    row = await fetch_one(
        """
        SELECT
            sess.id,
            sess.user_id,
            sess.souler_id,
            sess.title,
            sess.chapter_id,
            jsonb_build_object(
                'id', s.id,
                'name', s.name,
                'bio', s.bio
            ) AS souler,
            CASE
                WHEN c.id IS NULL THEN NULL
                ELSE jsonb_build_object(
                    'id', c.id,
                    'souler_id', c.souler_id,
                    'seq', c.seq,
                    'title', c.title,
                    'subtitle', c.subtitle,
                    'task', c.task
                )
            END AS chapter
        FROM public.sessions AS sess
        JOIN public.soulers AS s
            ON s.id = sess.souler_id
        LEFT JOIN public.chapters AS c
            ON c.id = sess.chapter_id
        WHERE sess.id = CAST(%(session_id)s AS uuid)
          AND sess.user_id = CAST(%(user_id)s AS uuid)
        """,
        {"user_id": user_id, "session_id": session_id},
    )
    if not row:
        raise ValueError("Session not found")

    chapter = row.get("chapter")
    parsed_chapter = to_chapter(chapter) if chapter else None
    return {
        "id": str(row.get("id")),
        "souler_id": str(row.get("souler_id")),
        "title": str(row.get("title", "")),
        "souler": to_souler(row.get("souler")),
        "chapter": parsed_chapter,
    }


async def create_session(
    user_id: str,
    souler_id: str,
    title: str = "",
    chapter_id: str | None = None,
) -> str:
    row = await execute_fetch_one(
        """
        INSERT INTO public.sessions (user_id, souler_id, title, chapter_id)
        VALUES (
            CAST(%(user_id)s AS uuid),
            CAST(%(souler_id)s AS uuid),
            %(title)s,
            CAST(%(chapter_id)s AS uuid)
        )
        RETURNING id
        """,
        {
            "user_id": user_id,
            "souler_id": souler_id,
            "title": title,
            "chapter_id": chapter_id,
        },
    )
    if not row or not row.get("id"):
        raise ValueError("Failed to create session")
    return str(row["id"])


async def delete_session(user_id: str, session_id: str) -> None:
    await execute(
        """
        DELETE FROM public.sessions
        WHERE id = CAST(%(session_id)s AS uuid)
          AND user_id = CAST(%(user_id)s AS uuid)
        """,
        {"user_id": user_id, "session_id": session_id},
    )


async def update_session_title(
    user_id: str,
    session_id: str,
    title: str,
    *,
    timeout: float | None = None,
) -> None:
    await execute(
        """
        UPDATE public.sessions
        SET title = %(title)s
        WHERE id = CAST(%(session_id)s AS uuid)
          AND user_id = CAST(%(user_id)s AS uuid)
        """,
        {"user_id": user_id, "session_id": session_id, "title": title},
        timeout=timeout,
    )


async def touch_session(
    user_id: str,
    session_id: str,
    *,
    timeout: float | None = None,
) -> None:
    await execute(
        """
        UPDATE public.sessions
        SET updated_at = %(updated_at)s
        WHERE id = CAST(%(session_id)s AS uuid)
          AND user_id = CAST(%(user_id)s AS uuid)
        """,
        {
            "user_id": user_id,
            "session_id": session_id,
            "updated_at": datetime.now(timezone.utc),
        },
        timeout=timeout,
    )
