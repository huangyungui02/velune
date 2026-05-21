from __future__ import annotations

from app.domain.types import Chapter, Message, Role, Session, Souler

from ._executor import run_sync
from . import auth, content, credit, messages, resonance, session

__all__ = [
    "Role",
    "Souler",
    "Chapter",
    "Session",
    "Message",
    "get_user_id_from_auth_header",
    "get_session_by_id",
    "get_souler_by_id",
    "get_chapter_by_id",
    "create_session",
    "delete_session",
    "update_session_title",
    "touch_session",
    "get_recent_messages",
    "insert_message",
    "consume_stardust",
    "refund_stardust",
    "create_or_update_resonance",
]


async def get_user_id_from_auth_header(authorization: str | None) -> str:
    return await run_sync(auth.get_user_id_from_auth_header, authorization)


async def get_session_by_id(user_id: str, session_id: str) -> Session:
    return await run_sync(session.get_session_by_id, user_id, session_id)


async def get_souler_by_id(souler_id: str) -> Souler:
    return await run_sync(content.get_souler_by_id, souler_id)


async def get_chapter_by_id(chapter_id: str) -> Chapter:
    return await run_sync(content.get_chapter_by_id, chapter_id)


async def create_session(
    user_id: str,
    souler_id: str,
    title: str = "",
    chapter_id: str | None = None,
) -> str:
    return await run_sync(
        session.create_session,
        user_id,
        souler_id,
        title,
        chapter_id,
    )


async def delete_session(user_id: str, session_id: str) -> None:
    await run_sync(session.delete_session, user_id, session_id)


async def update_session_title(
    user_id: str,
    session_id: str,
    title: str,
    *,
    timeout: float | None = None,
) -> None:
    await run_sync(
        session.update_session_title,
        user_id,
        session_id,
        title,
        timeout=timeout,
    )


async def touch_session(
    user_id: str,
    session_id: str,
    *,
    timeout: float | None = None,
) -> None:
    await run_sync(session.touch_session, user_id, session_id, timeout=timeout)


async def get_recent_messages(user_id: str, session_id: str) -> list[Message]:
    return await run_sync(messages.get_recent_messages, user_id, session_id)


async def insert_message(
    user_id: str,
    souler_id: str,
    session_id: str,
    role: Role,
    content: str,
    *,
    timeout: float | None = None,
) -> dict[str, str]:
    return await run_sync(
        messages.insert_message,
        user_id,
        souler_id,
        session_id,
        role,
        content,
        timeout=timeout,
    )


async def consume_stardust(user_id: str, amount: int) -> None:
    await run_sync(credit.consume_stardust, user_id, amount)


async def refund_stardust(user_id: str, amount: int) -> None:
    await run_sync(credit.refund_stardust, user_id, amount)


async def create_or_update_resonance(
    user_id: str,
    souler_id: str,
    last_session_id: str | None,
    *,
    timeout: float | None = None,
) -> None:
    await run_sync(
        resonance.create_or_update_resonance,
        user_id,
        souler_id,
        last_session_id,
        timeout=timeout,
    )
