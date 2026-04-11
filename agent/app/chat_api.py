from __future__ import annotations

import asyncio
import logging
from collections.abc import AsyncIterator, Callable
from dataclasses import dataclass
from typing import TypeVar
from uuid import UUID

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse, StreamingResponse
from starlette.requests import ClientDisconnect

from app.config import get_settings
from app.echo_nodes import SUPPORTED_LANGS
from app.echo_logic import Lang
from app.errors import (
    CreditLimitError,
    credit_error_payload,
    error_log_payload,
    error_message,
)
from app.llm import complete_text, stream_text
from app.sse import emit_once, sse_event, sse_response
from app.supabase_repo import (
    EchoContext,
    MessageRow,
    SessionContext,
    Souler,
    bind_echo_session_if_missing,
    consume_chat_credit,
    create_or_update_resonance,
    create_session,
    delete_session,
    get_echo_context,
    get_recent_messages,
    get_session_by_id,
    get_souler_by_id,
    get_user_id_from_auth_header,
    insert_message,
    refund_stardust,
    touch_session,
    update_session_title,
)

router = APIRouter()
logger = logging.getLogger(__name__)
settings = get_settings()
T = TypeVar("T")
CHAT_CREDIT_COST = 1
CHAT_MODEL = "qwen-plus"


def _normalize_uuid(value: str) -> str:
    trimmed = value.strip()
    if not trimmed:
        return ""
    return str(UUID(trimmed))


@dataclass(frozen=True)
class PreparedChat:
    user_id: str
    session: SessionContext
    lang: Lang
    content: str
    is_new_session: bool
    prompt_messages: list[dict[str, str]]


def _sanitize_title(raw: str, lang: Lang) -> str:
    trimmed = raw.strip().strip("\"'`")
    if not trimmed:
        return "新对话" if lang == "chs" else "New Chat"

    if lang == "chs":
        return trimmed[:16]

    return " ".join(trimmed.split()[:8])


def _build_system_prompt(name: str, lang: Lang) -> str:
    template: dict[Lang, str] = {
        "chs": "请以{name}的风格和用户进行深度对话",
        "en": "Please have a deep conversation with the user in the style of {name}.",
    }
    return template[lang].format(name=name)


async def _generate_session_title(
    user_content: str,
    reply_content: str,
    lang: Lang,
    *,
    model: str,
) -> str:
    system_prompt = (
        "根据用户消息和助手回复生成简洁聊天标题。限制 12 个字以内，不要标点，不要引号，只返回标题文本。"
        if lang == "chs"
        else "Create a concise chat title based on the user message and assistant reply. "
        "Keep it under 8 words, no punctuation, no quotes, and return only title text."
    )
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


async def _run_blocking(
    label: str,
    func: Callable[..., T],
    *args: object,
    timeout: float | None = None,
) -> T:
    try:
        return await asyncio.wait_for(
            asyncio.to_thread(func, *args),
            timeout=timeout or settings.REPO_TIMEOUT_SECONDS,
        )
    except asyncio.TimeoutError as error:
        raise TimeoutError(f"{label} timed out") from error


async def _stream_with_timeout(
    chunks: AsyncIterator[str],
    *,
    first_chunk_timeout: float,
    idle_timeout: float,
) -> AsyncIterator[str]:
    iterator = chunks.__aiter__()
    next_timeout = first_chunk_timeout
    try:
        while True:
            try:
                chunk = await asyncio.wait_for(
                    iterator.__anext__(), timeout=next_timeout
                )
            except StopAsyncIteration:
                return
            except asyncio.TimeoutError as error:
                raise TimeoutError("Model response timed out") from error

            next_timeout = idle_timeout
            yield chunk
    finally:
        aclose = getattr(iterator, "aclose", None)
        if callable(aclose):
            await aclose()


async def _refund_stardust_safely(
    user_id: str,
    amount: int,
    *,
    reason: str,
) -> None:
    if amount <= 0:
        return

    try:
        await _run_blocking(
            "Refund stardust",
            refund_stardust,
            user_id,
            amount,
        )
    except Exception as refund_error:  # noqa: BLE001
        logger.error(
            "Failed to refund stardust: reason=%s user_id=%s amount=%s error=%s",
            reason,
            user_id,
            amount,
            error_log_payload(refund_error),
        )


def _build_prompt_messages(
    session: SessionContext,
    history: list[MessageRow],
    content: str,
    lang: Lang,
) -> list[dict[str, str]]:
    prompt_messages: list[dict[str, str]] = [
        {
            "role": "system",
            "content": _build_system_prompt(
                session["souler"]["name"],
                lang,
            ),
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


async def _prepare_chat_request(
    request: Request,
    lang: Lang,
    log_stage: Callable[[str], None],
) -> PreparedChat:
    user_id = await _run_blocking(
        "Auth lookup",
        get_user_id_from_auth_header,
        request.headers.get("Authorization"),
    )
    body = await request.json()
    log_stage("request_parsed")

    try:
        session_id = _normalize_uuid(str(body.get("sessionId", "")))
        souler_id = _normalize_uuid(str(body.get("soulerId", "")))
        echo_id = _normalize_uuid(str(body.get("echoId", "")))
    except ValueError as error:
        raise ValueError("Invalid UUID in request body") from error
    content = str(body.get("content", "")).strip()
    if not content:
        raise ValueError("Missing content")

    await _run_blocking(
        "Credit check",
        consume_chat_credit,
        user_id,
    )
    log_stage("credit_checked")

    try:
        is_new_session = False
        needs_new_session = False
        should_insert_echo_context = False
        echo_context: EchoContext | None = None
        pending_souler: Souler | None = None
        session: SessionContext | None = None

        if session_id:
            session = await _run_blocking(
                "Load session",
                get_session_by_id,
                user_id,
                session_id,
            )
        else:
            if echo_id:
                echo_context = await _run_blocking(
                    "Load echo context",
                    get_echo_context,
                    user_id,
                    echo_id,
                )
                resolved_souler_id = echo_context["souler_id"]
                if souler_id and resolved_souler_id != souler_id:
                    raise ValueError("Echo souler does not match request soulerId")
                pending_souler = await _run_blocking(
                    "Load souler",
                    get_souler_by_id,
                    resolved_souler_id,
                )

                existing_echo_session_id = echo_context.get("session_id")
                if existing_echo_session_id:
                    session = await _run_blocking(
                        "Load echo session",
                        get_session_by_id,
                        user_id,
                        existing_echo_session_id,
                    )
                else:
                    needs_new_session = True
                    is_new_session = True
                    should_insert_echo_context = True
            else:
                if not souler_id:
                    raise ValueError("Missing soulerId for new conversation")
                pending_souler = await _run_blocking(
                    "Load souler",
                    get_souler_by_id,
                    souler_id,
                )
                needs_new_session = True
                is_new_session = True

        if needs_new_session:
            if not pending_souler:
                raise ValueError("Souler not found")

            created_session_id = await _run_blocking(
                "Create session",
                create_session,
                user_id,
                str(pending_souler["id"]),
            )
            created_session = {
                "id": created_session_id,
                "soulerId": str(pending_souler["id"]),
                "title": "",
                "souler": pending_souler,
            }

            if echo_id and should_insert_echo_context:
                bound_session_id = await _run_blocking(
                    "Bind echo session",
                    bind_echo_session_if_missing,
                    user_id,
                    echo_id,
                    created_session_id,
                )
                if bound_session_id != created_session_id:
                    should_insert_echo_context = False
                    is_new_session = False
                    try:
                        await _run_blocking(
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
                    session = await _run_blocking(
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
            await _run_blocking(
                "Insert glimmer context message",
                insert_message,
                user_id,
                session["soulerId"],
                session["id"],
                "user",
                echo_context["glimmer_content"],
            )
            await _run_blocking(
                "Insert echo context message",
                insert_message,
                user_id,
                session["soulerId"],
                session["id"],
                "assistant",
                echo_context["content"],
            )
        log_stage("session_ready")

        history = await _run_blocking(
            "Load message history",
            get_recent_messages,
            user_id,
            session["id"],
        )
        await _run_blocking(
            "Insert user message",
            insert_message,
            user_id,
            session["soulerId"],
            session["id"],
            "user",
            content,
        )
        log_stage("user_message_inserted")

        prompt_messages = _build_prompt_messages(session, history, content, lang)
        log_stage("prompt_ready")
        return PreparedChat(
            user_id=user_id,
            session=session,
            lang=lang,
            content=content,
            is_new_session=is_new_session,
            prompt_messages=prompt_messages,
        )
    except Exception:
        await _refund_stardust_safely(
            user_id,
            CHAT_CREDIT_COST,
            reason="chat_prepare_failed",
        )
        raise


@router.post("/{lang}/chat")
async def chat(lang: Lang, request: Request) -> StreamingResponse:
    lang = str(lang).strip().lower()
    if lang not in SUPPORTED_LANGS:
        return JSONResponse(
            {"error": "Invalid lang, must be one of: en, chs"}, status_code=400
        )

    started_at = asyncio.get_running_loop().time()

    def log_stage(stage: str) -> None:
        elapsed_ms = int((asyncio.get_running_loop().time() - started_at) * 1000)
        logger.info("chat stage=%s elapsed_ms=%s", stage, elapsed_ms)

    try:
        log_stage("request_received")
        prepared = await _prepare_chat_request(request, lang, log_stage)
    except CreditLimitError as error:
        return sse_response(emit_once(credit_error_payload(error)))
    except ValueError as error:
        return JSONResponse({"error": str(error)}, status_code=400)
    except Exception as error:  # noqa: BLE001
        logger.error("Failed before stream start: %s", error_log_payload(error))
        return sse_response(
            emit_once({"type": "error", "message": error_message(error)})
        )

    async def event_stream():
        should_refund_on_failure = True
        try:
            yield sse_event({"type": "ready", "sessionId": prepared.session["id"]})
            log_stage("stream_opened")

            assistant_chunks: list[str] = []
            async for delta in _stream_with_timeout(
                stream_text(
                    prepared.prompt_messages,
                    model=CHAT_MODEL,
                    temperature=settings.CHAT_TEMPERATURE,
                ),
                first_chunk_timeout=settings.LLM_FIRST_TOKEN_TIMEOUT_SECONDS,
                idle_timeout=settings.LLM_STREAM_IDLE_TIMEOUT_SECONDS,
            ):
                if not delta:
                    continue
                assistant_chunks.append(delta)
                yield sse_event({"type": "delta", "delta": delta})

            final_content = "".join(assistant_chunks).strip()
            if not final_content:
                raise ValueError("Empty assistant response")
            log_stage("model_completed")

            assistant_message = await _run_blocking(
                "Insert assistant message",
                insert_message,
                prepared.user_id,
                prepared.session["soulerId"],
                prepared.session["id"],
                "assistant",
                final_content,
            )
            log_stage("assistant_message_inserted")

            generated_title: str | None = None
            if prepared.is_new_session:
                generated_title = await asyncio.wait_for(
                    _generate_session_title(
                        prepared.content,
                        final_content,
                        prepared.lang,
                        model=CHAT_MODEL,
                    ),
                    timeout=settings.POST_STREAM_TIMEOUT_SECONDS,
                )
                await _run_blocking(
                    "Update session title",
                    update_session_title,
                    prepared.user_id,
                    prepared.session["id"],
                    generated_title,
                    timeout=settings.POST_STREAM_TIMEOUT_SECONDS,
                )
                log_stage("title_updated")

            await _run_blocking(
                "Touch session",
                touch_session,
                prepared.user_id,
                prepared.session["id"],
                timeout=settings.POST_STREAM_TIMEOUT_SECONDS,
            )
            await _run_blocking(
                "Update resonance",
                create_or_update_resonance,
                prepared.user_id,
                prepared.session["soulerId"],
                prepared.session["id"],
                generated_title or prepared.session["title"],
                timeout=settings.POST_STREAM_TIMEOUT_SECONDS,
            )
            log_stage("stream_done")

            yield sse_event(
                {
                    "type": "done",
                    "sessionId": prepared.session["id"],
                    "title": generated_title,
                    "assistantMessage": {
                        "id": assistant_message["id"],
                        "createdAt": assistant_message["created_at"],
                    },
                }
            )
            should_refund_on_failure = False
        except CreditLimitError as error:
            if should_refund_on_failure:
                await _refund_stardust_safely(
                    prepared.user_id,
                    CHAT_CREDIT_COST,
                    reason="chat_stream_credit_error",
                )
            yield sse_event(credit_error_payload(error))
        except (ClientDisconnect, asyncio.CancelledError):
            logger.info("Chat stream closed by client.")
            return
        except Exception as error:  # noqa: BLE001
            if should_refund_on_failure:
                await _refund_stardust_safely(
                    prepared.user_id,
                    CHAT_CREDIT_COST,
                    reason="chat_stream_failed",
                )
            logger.error("Failed to process chat request: %s", error_log_payload(error))
            yield sse_event({"type": "error", "message": error_message(error)})

    return sse_response(event_stream())
