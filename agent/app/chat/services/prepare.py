from __future__ import annotations

import logging

from app.core.entities import Message, Session
from app.chat.repositories.messages import get_recent_messages, insert_message
from app.chat.preferences import ReplyLength, apply_reply_length_prompt
from app.chat.prompts import CHAT_SYSTEM, CHAPTER_SYSTEM
from app.chat.services.sessions import resolve_session
from app.chat.services.types import PreparedChat, StageLogger

logger = logging.getLogger(__name__)


async def prepare_chat(
    *,
    user_id: str,
    lang: str,
    model: str,
    session_id: str,
    souler_id: str,
    chapter_id: str,
    content: str,
    reply_length: ReplyLength,
    log_stage: StageLogger,
) -> PreparedChat:
    resolved = await resolve_session(
        user_id,
        session_id=session_id,
        souler_id=souler_id,
        chapter_id=chapter_id,
        lang=lang,
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

    prompt_messages = build_chat_history(
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
        model=model,
        is_new_session=resolved.is_new,
        should_generate_title=resolved.should_generate_title,
        prompt_messages=prompt_messages,
    )


def build_chat_history(
    session: Session,
    history: list[Message],
    content: str,
    lang: str,
    reply_length: ReplyLength = "standard",
) -> list[dict[str, str]]:
    chapter = session.get("chapter")
    if chapter:
        system_prompt = CHAPTER_SYSTEM[lang].format(
            souler_name=session["souler"]["name"],
            chapter_title=str(chapter.get("title", "")).strip(),
            chapter_subtitle=str(chapter.get("subtitle", "")).strip(),
            chapter_task=str(chapter.get("task", "")).strip(),
        )
    else:
        system_prompt = CHAT_SYSTEM[lang].format(name=session["souler"]["name"])

    prompt_messages: list[dict[str, str]] = [
        {
            "role": "system",
            "content": apply_reply_length_prompt(system_prompt, lang, reply_length),
        }
    ]

    for item in history:
        prompt_messages.append(
            {
                "role": "assistant" if item["role"] == "assistant" else "user",
                "content": str(item["content"]),
            }
        )

    prompt_messages.append({"role": "user", "content": content})
    return prompt_messages
