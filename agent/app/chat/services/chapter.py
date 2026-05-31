from __future__ import annotations

import logging
from uuid import UUID

from app.core.common import Lang
from app.core.config import get_settings
from app.core.errors import error_log_payload
from app.core.llm import DEFAULT_MODEL, complete_text
from app.chat.chapter_response import parse_chapter_response
from app.chat.preferences import (
    DEFAULT_REPLY_LENGTH,
    ReplyLength,
    apply_reply_length_prompt,
)
from app.chat.prompts import CHAPTER_OPENING, CHAPTER_SYSTEM
from app.chat.repositories.messages import insert_message
from app.chat.repositories.session import delete_session
from app.chat.services.sessions import (
    create_chapter_session,
    load_chapter_pair,
    sync_session_activity,
)

logger = logging.getLogger(__name__)
settings = get_settings()


async def start_chapter(
    *,
    user_id: str,
    souler_id: UUID,
    chapter_id: UUID,
    lang: Lang,
    reply_length: ReplyLength = DEFAULT_REPLY_LENGTH,
) -> dict[str, object]:
    created_session_id: str | None = None
    assistant_written = False

    try:
        souler, chapter = await load_chapter_pair(str(souler_id), str(chapter_id))
        session = await create_chapter_session(user_id, souler, chapter)
        created_session_id = session["id"]

        system_prompt = CHAPTER_SYSTEM[lang].format(
            souler_name=souler["name"],
            chapter_title=str(chapter.get("title", "")).strip(),
            chapter_subtitle=str(chapter.get("subtitle", "")).strip(),
            chapter_task=str(chapter.get("task", "")).strip(),
        )
        opening_raw = await complete_text(
            [
                {
                    "role": "system",
                    "content": apply_reply_length_prompt(
                        system_prompt,
                        lang,
                        reply_length,
                    ),
                },
                {"role": "user", "content": CHAPTER_OPENING[lang]},
            ],
            model=DEFAULT_MODEL,
            temperature=settings.CHAT_TEMPERATURE,
        )
        _, options = parse_chapter_response(opening_raw)
        opening_content = opening_raw.strip()
        if not opening_content:
            raise ValueError("Empty chapter opening response")

        assistant_message = await insert_message(
            user_id,
            str(souler_id),
            created_session_id,
            "assistant",
            opening_content,
        )
        assistant_written = True

        try:
            await sync_session_activity(user_id, created_session_id, str(souler_id))
        except Exception as side_effect_error:  # noqa: BLE001
            logger.warning(
                "Chapter session side effect failed: session_id=%s error=%s",
                created_session_id,
                error_log_payload(side_effect_error),
            )

        return {
            "session_id": created_session_id,
            "souler_id": str(souler_id),
            "chapter_id": chapter["id"],
            "title": chapter["title"],
            "assistant_message": {
                "id": assistant_message["id"],
                "created_at": assistant_message["created_at"],
                "content": opening_content,
            },
            "options": options,
        }
    except Exception:
        if created_session_id and not assistant_written:
            try:
                await delete_session(user_id, created_session_id)
            except Exception as cleanup_error:  # noqa: BLE001
                logger.warning(
                    "Failed to cleanup chapter session: session_id=%s error=%s",
                    created_session_id,
                    error_log_payload(cleanup_error),
                )
        raise
