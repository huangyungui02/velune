from __future__ import annotations

from collections.abc import Callable

from app.core import Lang, normalize_uuid
from app.repositories import get_recent_messages, insert_message
from app.services.chat.preferences import normalize_reply_length
from app.services.chat.prompts import build_prompt_messages
from app.services.chat.session import resolve_session
from app.services.chat.types import PreparedChat


async def prepare_chat(
    *,
    user_id: str,
    lang: Lang,
    body: dict[str, object],
    log_stage: Callable[[str], None],
) -> PreparedChat:
    try:
        session_id = normalize_uuid(str(body.get("sessionId", "")))
        souler_id = normalize_uuid(str(body.get("soulerId", "")))
        chapter_id = normalize_uuid(str(body.get("chapterId", "")))
    except ValueError as error:
        raise ValueError("Invalid UUID in request body") from error

    content = str(body.get("content", "")).strip()
    if not content:
        raise ValueError("Missing content")

    reply_length = normalize_reply_length(body.get("replyLength"))

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

    prompt_messages = build_prompt_messages(session, history, content, lang, reply_length)
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
