from __future__ import annotations

import logging
from collections.abc import Callable
from uuid import UUID

from fastapi import Request

from app.shared import Lang
from app.billing import CHAT_STARDUST_COST, refund_stardust_safely
from app.errors import error_log_payload
from app.repositories import (
    ChapterContext,
    EchoContext,
    SessionContext,
    Souler,
    bind_echo_session_if_missing,
    consume_stardust,
    create_session,
    delete_session,
    get_chapter_by_id,
    get_echo_context,
    get_recent_messages,
    get_session_by_id,
    get_souler_by_id,
    get_user_id_from_auth_header,
    insert_message,
)

from .shared import (
    PreparedChat,
    build_prompt_messages,
    run_blocking,
)

logger = logging.getLogger(__name__)


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
        echo_id = normalize_uuid(str(body.get("echoId", "")))
        chapter_id = normalize_uuid(str(body.get("chapterId", "")))
    except ValueError as error:
        raise ValueError("Invalid UUID in request body") from error
    content = str(body.get("content", "")).strip()
    if not content:
        raise ValueError("Missing content")

    await run_blocking("Credit check", consume_stardust, user_id, CHAT_STARDUST_COST)
    log_stage("credit_checked")

    try:
        is_new_session = False
        needs_new_session = False
        should_insert_echo_context = False
        should_generate_title = False
        echo_context: EchoContext | None = None
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
            if echo_id:
                echo_context = await run_blocking(
                    "Load echo context",
                    get_echo_context,
                    user_id,
                    echo_id,
                )
                resolved_souler_id = echo_context["souler_id"]
                if souler_id and resolved_souler_id != souler_id:
                    raise ValueError("Echo souler does not match request soulerId")
                pending_souler = await run_blocking(
                    "Load souler",
                    get_souler_by_id,
                    resolved_souler_id,
                )

                existing_echo_session_id = echo_context.get("session_id")
                if existing_echo_session_id:
                    session = await run_blocking(
                        "Load echo session",
                        get_session_by_id,
                        user_id,
                        existing_echo_session_id,
                    )
                else:
                    needs_new_session = True
                    is_new_session = True
                    should_insert_echo_context = True
                    should_generate_title = True
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

            if echo_id and should_insert_echo_context:
                bound_session_id = await run_blocking(
                    "Bind echo session",
                    bind_echo_session_if_missing,
                    user_id,
                    echo_id,
                    created_session_id,
                )
                if bound_session_id != created_session_id:
                    should_insert_echo_context = False
                    is_new_session = False
                    should_generate_title = False
                    try:
                        await run_blocking(
                            "Delete orphan session",
                            delete_session,
                            user_id,
                            created_session_id,
                        )
                    except Exception as cleanup_error:  # noqa: BLE001
                        logger.warning(
                            "Failed to cleanup orphan session: %s",
                            error_log_payload(cleanup_error),
                        )
                    session = await run_blocking(
                        "Load bound session",
                        get_session_by_id,
                        user_id,
                        bound_session_id,
                    )
                else:
                    session = created_session
            else:
                session = created_session

        if not session:
            raise ValueError("Session not found")

        if should_insert_echo_context and echo_context:
            await run_blocking(
                "Insert glimmer context message",
                insert_message,
                user_id,
                str(session["soulerId"]),
                str(session["id"]),
                "user",
                echo_context["glimmer_content"],
            )
            await run_blocking(
                "Insert echo context message",
                insert_message,
                user_id,
                str(session["soulerId"]),
                str(session["id"]),
                "assistant",
                echo_context["content"],
            )
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

        prompt_messages = build_prompt_messages(session, history, content, lang)
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
