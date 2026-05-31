from __future__ import annotations

import asyncio

from app.core.entities import Chapter, Session, Souler
from app.chat.repositories.chapters import get_chapter_by_id
from app.chat.repositories.session import create_session, get_session_by_id, touch_session
from app.chat.services.types import SessionResolution
from app.starsea.repositories.resonance import create_or_update_resonance
from app.soulers.repositories.content import get_souler_by_id


async def load_chapter_pair(souler_id: str, chapter_id: str) -> tuple[Souler, Chapter]:
    souler, chapter = await asyncio.gather(
        get_souler_by_id(souler_id),
        get_chapter_by_id(chapter_id),
    )
    if chapter["souler_id"] != souler["id"]:
        raise ValueError("Chapter does not belong to souler")
    return souler, chapter


async def create_chapter_session(
    user_id: str,
    souler: Souler,
    chapter: Chapter,
) -> Session:
    session_id = await create_session(
        user_id,
        souler["id"],
        chapter["title"],
        chapter["id"],
    )
    return {
        "id": session_id,
        "souler_id": souler["id"],
        "title": chapter["title"],
        "souler": souler,
        "chapter": chapter,
    }


async def resolve_session(
    user_id: str,
    *,
    session_id: str,
    souler_id: str,
    chapter_id: str,
) -> SessionResolution:
    if session_id:
        return SessionResolution(
            session=await get_session_by_id(user_id, session_id),
            is_new=False,
            should_generate_title=False,
        )

    if not souler_id:
        raise ValueError("Missing soulerId for new conversation")

    if chapter_id:
        souler, chapter = await load_chapter_pair(souler_id, chapter_id)
        session = await create_chapter_session(user_id, souler, chapter)
        return SessionResolution(session=session, is_new=True, should_generate_title=False)

    souler = await get_souler_by_id(souler_id)
    created_id = await create_session(user_id, souler["id"])
    session: Session = {
        "id": created_id,
        "souler_id": souler["id"],
        "title": "",
        "souler": souler,
        "chapter": None,
    }
    return SessionResolution(session=session, is_new=True, should_generate_title=True)


async def sync_session_activity(
    user_id: str,
    session_id: str,
    souler_id: str,
) -> None:
    await touch_session(user_id, session_id)
    await create_or_update_resonance(
        user_id,
        souler_id,
        session_id,
    )
