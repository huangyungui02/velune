from __future__ import annotations

import logging
from uuid import UUID

from app.billing import (
    CHAT_STARDUST_COST,
    consume_stardust_if_enabled,
    refund_stardust_safely,
)
from app.config import get_settings
from app.core.lang import Lang
from app.errors import error_log_payload
from app.infra.blocking import run_blocking
from app.infra.llm import DEFAULT_MODEL, complete_text
from app.repositories import (
    create_or_update_resonance,
    create_session,
    delete_session,
    get_chapter_by_id,
    get_souler_by_id,
    insert_message,
    touch_session,
)
from app.services.chat.chapters.prompt import build_chapter_opening_messages
from app.services.chat.chapters.reply import parse_chapter_combined_response
from app.services.chat.preferences import ReplyLength

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
    await consume_stardust_if_enabled(
        user_id,
        CHAT_STARDUST_COST,
        run_blocking=run_blocking,
    )

    created_session_id: str | None = None
    assistant_written = False

    try:
        souler = await run_blocking("Load souler", get_souler_by_id, str(souler_id))
        chapter = await run_blocking("Load chapter", get_chapter_by_id, str(chapter_id))
        if chapter["souler_id"] != str(souler_id):
            raise ValueError("Chapter does not belong to souler")

        created_session_id = await run_blocking(
            "Create session",
            create_session,
            user_id,
            str(souler_id),
            chapter["title"],
            chapter["id"],
        )

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
        _, options = parse_chapter_combined_response(opening_raw)
        opening_storage_content = opening_raw.strip()
        if not opening_storage_content:
            raise ValueError("Empty chapter opening response")

        assistant_message = await run_blocking(
            "Insert assistant message",
            insert_message,
            user_id,
            str(souler_id),
            created_session_id,
            "assistant",
            opening_storage_content,
        )
        assistant_written = True

        try:
            await run_blocking("Touch session", touch_session, user_id, created_session_id)
            await run_blocking(
                "Update resonance",
                create_or_update_resonance,
                user_id,
                str(souler_id),
                created_session_id,
            )
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
                await run_blocking(
                    "Delete session",
                    delete_session,
                    user_id,
                    created_session_id,
                )
            except Exception as cleanup_error:  # noqa: BLE001
                logger.warning(
                    "Failed to cleanup chapter session: session_id=%s error=%s",
                    created_session_id,
                    error_log_payload(cleanup_error),
                )

        await refund_stardust_safely(
            user_id,
            CHAT_STARDUST_COST,
            reason="chapter_session_start_failed",
            run_blocking=run_blocking,
        )
        raise
