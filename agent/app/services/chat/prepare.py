from __future__ import annotations

from collections.abc import Callable

from app.repositories import get_recent_messages, insert_message
from app.schemas.common import Lang
from app.services.chat.preferences import ReplyLength
from app.services.chat.prompts import build_prompt_messages
from app.services.chat.session import resolve_session
from app.services.chat.types import PreparedChat


async def prepare_chat(
    *,
    user_id: str,
    lang: Lang,
    session_id: str,
    souler_id: str,
    chapter_id: str,
    content: str,
    reply_length: ReplyLength,
    log_stage: Callable[[str], None],
) -> PreparedChat:
    resolved = await resolve_session(
        user_id,
        session_id=session_id,
        souler_id=souler_id,
        chapter_id=chapter_id,
    )
    session = resolved.session
    log_stage("session_ready")

    history = await get_recent_messages(user_id, session["id"])
    await insert_message(
        user_id,
        session["souler_id"],
        session["id"],
        "user",
        content,
    )
    log_stage("user_message_inserted")

    prompt_messages = build_prompt_messages(
        session,
        history,
        content,
        lang,
        reply_length,
    )
    log_stage("prompt_ready")

    return PreparedChat(
        user_id=user_id,
        session=session,
        lang=lang,
        content=content,
        is_new_session=resolved.is_new,
        should_generate_title=resolved.should_generate_title,
        prompt_messages=prompt_messages,
    )
