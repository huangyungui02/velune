from __future__ import annotations

import asyncio

from app.config import get_settings
from app.repositories import insert_message, update_session_title
from app.services.chat.prompts import generate_session_title
from app.services.chat.session import sync_session_activity
from app.services.chat.types import PreparedChat

settings = get_settings()


async def persist_chat_response(
    prepared: PreparedChat,
    *,
    storage_content: str,
    final_content: str,
) -> tuple[dict[str, str], str | None]:
    assistant_message = await insert_message(
        prepared.user_id,
        prepared.session["souler_id"],
        prepared.session["id"],
        "assistant",
        storage_content,
    )

    generated_title: str | None = None
    if prepared.is_new_session and prepared.should_generate_title:
        generated_title = await asyncio.wait_for(
            generate_session_title(
                prepared.content,
                final_content,
                prepared.lang,
            ),
            timeout=settings.POST_STREAM_TIMEOUT_SECONDS,
        )
        await update_session_title(
            prepared.user_id,
            prepared.session["id"],
            generated_title,
            timeout=settings.POST_STREAM_TIMEOUT_SECONDS,
        )

    await sync_session_activity(
        prepared.user_id,
        prepared.session["id"],
        prepared.session["souler_id"],
        timeout=settings.POST_STREAM_TIMEOUT_SECONDS,
    )

    return assistant_message, generated_title
