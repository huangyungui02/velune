from __future__ import annotations

import logging
from uuid import UUID

from app.core.config import get_settings
from app.core import Lang
from app.core.errors import error_log_payload
from app.core.llm import DEFAULT_MODEL, complete_text
from app.repositories import delete_session, insert_message
from app.services.billing import CHAT_STARDUST_COST, stardust_charge
from app.services.chat.chapters.prompt import build_chapter_opening_messages
from app.services.chat.chapters.response import parse_chapter_response
from app.services.chat.preferences import ReplyLength
from app.services.chat.session import create_chapter_session, load_chapter_pair, sync_session_activity

logger = logging.getLogger(__name__)
settings = get_settings()


async def start_chapter_session(
    *,
    user_id: str,
    souler_id: UUID,
    chapter_id: UUID,
    lang: Lang,
    reply_length: ReplyLength = "standard",
) -> dict[str, object]:
    created_session_id: str | None = None
    assistant_written = False

    async with stardust_charge(
        user_id,
        CHAT_STARDUST_COST,
        reason="chapter_session_start_failed",
    ):
        try:
            souler, chapter = await load_chapter_pair(str(souler_id), str(chapter_id))
            session = await create_chapter_session(user_id, souler, chapter)
            created_session_id = session["id"]

            opening_raw = await complete_text(
                build_chapter_opening_messages(
                    souler_name=souler["name"],
                    chapter=chapter,
                    lang=lang,
                    reply_length=reply_length,
                ),
                model=DEFAULT_MODEL,
                temperature=settings.CHAT_TEMPERATURE,
            )
            _, options = parse_chapter_response(opening_raw)
            opening_storage_content = opening_raw.strip()
            if not opening_storage_content:
                raise ValueError("Empty chapter opening response")

            assistant_message = await insert_message(
                user_id,
                str(souler_id),
                created_session_id,
                "assistant",
                opening_storage_content,
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
                    "content": opening_storage_content,
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
