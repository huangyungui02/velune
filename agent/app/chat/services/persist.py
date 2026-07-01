from __future__ import annotations

import logging

from app.core.config import get_settings
from app.core.llm import DEFAULT_MODEL, complete_text

from app.chat.repositories.messages import insert_message
from app.chat.repositories.session import update_session_title
from app.chat.prompts import TITLE_GENERATION
from app.chat.services.sessions import sync_session_activity
from app.chat.services.types import PreparedChat

logger = logging.getLogger(__name__)
settings = get_settings()


async def save_response(
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
        generated_title = await _generate_session_title(
            prepared.content,
            final_content,
            prepared.lang,
        )
        await update_session_title(
            prepared.user_id,
            prepared.session["id"],
            generated_title,
        )

    await sync_session_activity(
        prepared.user_id,
        prepared.session["id"],
        prepared.session["souler_id"],
    )

    return assistant_message, generated_title


async def _generate_session_title(
    user_content: str,
    reply_content: str,
    lang: str,
    *,
    model: str = DEFAULT_MODEL,
) -> str:
    system_prompt = TITLE_GENERATION[lang]
    raw = await complete_text(
        [
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": f"User:\n{user_content}\n\nAssistant:\n{reply_content}",
            },
        ],
        model=model,
        temperature=settings.MODEL_S_TEMPERATURE,
    )
    return _sanitize_title(raw, lang)


def _sanitize_title(raw: str, lang: str) -> str:
    trimmed = raw.strip().strip('"\'`')
    if not trimmed:
        return "未命名会话" if lang == "zh" else "Untitled Session"

    if lang == "zh":
        return trimmed[:16]

    return " ".join(trimmed.split()[:8])
