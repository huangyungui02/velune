from __future__ import annotations

from collections.abc import Callable
from uuid import UUID

from fastapi import Request

from app.billing import (
    CHAT_STARDUST_COST,
    consume_stardust_if_enabled,
    refund_stardust_safely,
)
from app.core.lang import Lang
from app.infra.blocking import run_blocking
from app.repositories import (
    ChapterContext,
    SessionContext,
    Souler,
    create_session,
    get_chapter_by_id,
    get_recent_messages,
    get_session_by_id,
    get_souler_by_id,
    get_user_id_from_auth_header,
    insert_message,
)
from app.services.chat.preferences import normalize_reply_length
from app.services.chat.prompts import build_prompt_messages
from app.services.chat.types import PreparedChat


def normalize_uuid(value: str) -> str:
    trimmed = value.strip()
    if not trimmed:
        return ""
    return str(UUID(trimmed))


async def prepare_chat_request(
    request: Request,
    lang: Lang,
    log_stage: Callable[[str], None],
) -> PreparedChat:
    user_id = await run_blocking(
        "Auth lookup",
        get_user_id_from_auth_header,
        request.headers.get("Authorization"),
    )
    body = await request.json()
    log_stage("request_parsed")

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

    await consume_stardust_if_enabled(
        user_id,
        CHAT_STARDUST_COST,
        run_blocking=run_blocking,
    )
    log_stage("credit_checked")

    try:
        is_new_session = False
        needs_new_session = False
        should_generate_title = False
        pending_souler: Souler | None = None
        pending_chapter: ChapterContext | None = None
        session: SessionContext | None = None

        if session_id:
            session = await run_blocking(
                "Load session",
                get_session_by_id,
                user_id,
                session_id,
            )
        else:
            if not souler_id:
                raise ValueError("Missing soulerId for new conversation")
            pending_souler = await run_blocking(
                "Load souler",
                get_souler_by_id,
                souler_id,
            )
            if chapter_id:
                pending_chapter = await run_blocking(
                    "Load chapter",
                    get_chapter_by_id,
                    chapter_id,
                )
                if pending_chapter["souler_id"] != str(pending_souler["id"]):
                    raise ValueError("Chapter does not belong to souler")
            needs_new_session = True
            is_new_session = True
            should_generate_title = pending_chapter is None

        if needs_new_session:
            if not pending_souler:
                raise ValueError("Souler not found")

            initial_title = str(pending_chapter["title"]) if pending_chapter else ""
            initial_chapter_id = str(pending_chapter["id"]) if pending_chapter else None
            created_session_id = await run_blocking(
                "Create session",
                create_session,
                user_id,
                str(pending_souler["id"]),
                initial_title,
                initial_chapter_id,
            )
            created_session: SessionContext = {
                "id": created_session_id,
                "soulerId": str(pending_souler["id"]),
                "title": initial_title,
                "souler": pending_souler,
                "chapter": pending_chapter,
            }

            session = created_session

        if not session:
            raise ValueError("Session not found")

        log_stage("session_ready")

        history = await run_blocking(
            "Load message history",
            get_recent_messages,
            user_id,
            str(session["id"]),
        )
        await run_blocking(
            "Insert user message",
            insert_message,
            user_id,
            str(session["soulerId"]),
            str(session["id"]),
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
            is_new_session=is_new_session,
            should_generate_title=should_generate_title,
            prompt_messages=prompt_messages,
        )
    except Exception:
        await refund_stardust_safely(
            user_id,
            CHAT_STARDUST_COST,
            reason="chat_prepare_failed",
            run_blocking=run_blocking,
        )
        raise
