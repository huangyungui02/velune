from __future__ import annotations

import asyncio
import logging
from collections.abc import Awaitable, Callable
from typing import Any

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from starlette.requests import ClientDisconnect

from app.echo_nodes import SUPPORTED_LANGS
from app.echo_logic import EchoGraphFailedError, Lang, invoke_echo_graph
from app.errors import CreditLimitError, credit_error_payload, error_log_payload, error_message
from app.sse import sse_event, sse_response
from app.supabase_repo import (
    consume_echo_credit,
    ensure_glimmer,
    get_user_id_from_auth_header,
    list_glimmer_echoes,
    refund_stardust,
    update_glimmer_status,
)

router = APIRouter()
logger = logging.getLogger(__name__)
ECHO_STARDUST_COST = 5

type Send = Callable[[dict[str, Any]], Awaitable[None]]


def _fail_glimmer_safely(glimmer_id: str) -> None:
    try:
        update_glimmer_status(glimmer_id, "failed")
    except Exception:  # noqa: BLE001
        pass


async def _emit_existing_echoes(
    send: Send,
    glimmer_id: str,
) -> int:
    echoed = 0
    for row in list_glimmer_echoes(glimmer_id):
        await send(_echo_event_payload(row))
        echoed += 1
    return echoed


def _echo_event_payload(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "type": "echo",
        "echo": {
            "id": row.get("id"),
            "glimmerId": row.get("glimmer_id"),
            "soulerId": row.get("souler_id"),
            "soulerName": row.get("souler_name"),
            "content": row.get("content"),
        },
    }


def _done_event_payload() -> dict[str, Any]:
    return {
        "type": "done",
    }


async def _refund_stardust_safely(
    user_id: str,
    amount: int,
    *,
    reason: str,
) -> None:
    if amount <= 0:
        return

    try:
        refund_stardust(user_id, amount)
    except Exception as refund_error:  # noqa: BLE001
        logger.error(
            "Failed to refund stardust: reason=%s user_id=%s amount=%s error=%s",
            reason,
            user_id,
            amount,
            error_log_payload(refund_error),
        )


async def _compose_worker(
    *,
    request: Request,
    lang: Lang,
    glimmer_id: str,
    content: str,
    send: Send,
) -> None:
    processing_started = False
    generation_finished = False
    user_id: str | None = None
    charged_credits = 0
    try:
        user_id = get_user_id_from_auth_header(request.headers.get("Authorization"))
        glimmer = ensure_glimmer(user_id, glimmer_id, content)
        status = str(glimmer.get("status", "pending"))

        await send(
            {
                "type": "ready",
                "glimmerId": glimmer_id,
                "status": status,
            }
        )

        replayed = await _emit_existing_echoes(send, glimmer_id)
        if replayed > 0 or status in {"complete", "incomplete"}:
            await send(_done_event_payload())
            return

        if status == "processing":
            await send(
                {
                    "type": "error",
                    "message": "Glimmer is already processing, retry later.",
                }
            )
            return

        if status not in {"pending", "failed"}:
            await send(
                {
                    "type": "error",
                    "message": f"Invalid glimmer status: {status}",
                }
            )
            return

        update_glimmer_status(glimmer_id, "processing")
        processing_started = True
        consume_echo_credit(user_id, amount=ECHO_STARDUST_COST)
        charged_credits = ECHO_STARDUST_COST

        result = await invoke_echo_graph(
            user_id=user_id,
            glimmer_id=glimmer_id,
            glimmer_content=str(glimmer.get("content", content)),
            num=ECHO_STARDUST_COST,
            lang=lang,  # type: ignore[arg-type]
            on_echo=lambda echo_row: send(_echo_event_payload(echo_row)),
        )
        generation_finished = True

        await _refund_stardust_safely(
            user_id,
            result.refund_credits,
            reason=f"partial echo failure for glimmer {glimmer_id}",
        )

        update_glimmer_status(
            glimmer_id,
            "complete" if result.completed else "incomplete",
        )

        await send(_done_event_payload())
    except (ClientDisconnect, asyncio.CancelledError):
        if processing_started and not generation_finished:
            _fail_glimmer_safely(glimmer_id)
        return
    except Exception as error:  # noqa: BLE001
        if processing_started and not generation_finished:
            _fail_glimmer_safely(glimmer_id)

        refund_amount = 0
        if not generation_finished:
            refund_amount = charged_credits
        if isinstance(error, EchoGraphFailedError):
            refund_amount = max(refund_amount, error.refund_credits)

        if user_id and refund_amount > 0:
            await _refund_stardust_safely(
                user_id,
                refund_amount,
                reason=f"failed echo compose for glimmer {glimmer_id}",
            )

        if isinstance(error, CreditLimitError):
            await send(credit_error_payload(error))
        else:
            logger.error(
                "Failed to compose glimmer %s: %s",
                glimmer_id,
                error_log_payload(error),
            )
            await send(
                {
                    "type": "error",
                    "message": error_message(error),
                }
            )


def _compose_stream(
    *,
    request: Request,
    lang: Lang,
    glimmer_id: str,
    content: str,
):
    async def event_stream():
        queue: asyncio.Queue[dict[str, Any] | None] = asyncio.Queue()
        stream_closed = asyncio.Event()

        async def send(payload: dict[str, Any]) -> None:
            if stream_closed.is_set():
                return
            await queue.put(payload)

        async def worker() -> None:
            try:
                await _compose_worker(
                    request=request,
                    lang=lang,
                    glimmer_id=glimmer_id,
                    content=content,
                    send=send,
                )
            finally:
                if not stream_closed.is_set():
                    await queue.put(None)

        worker_task = asyncio.create_task(worker())
        try:
            while True:
                payload = await queue.get()
                if payload is None:
                    break
                yield sse_event(payload)
        except (ClientDisconnect, asyncio.CancelledError):
            stream_closed.set()
            return

        await worker_task

    return sse_response(event_stream())


@router.post("/{lang}/glimmers/compose")
async def compose_glimmer(lang: Lang, request: Request):
    lang = str(lang).strip().lower()
    if lang not in SUPPORTED_LANGS:
        return JSONResponse({"error": "Invalid lang, must be one of: en, chs"}, status_code=400)

    try:
        body = await request.json()
    except Exception:  # noqa: BLE001
        return JSONResponse({"error": "Invalid JSON body"}, status_code=400)

    glimmer_id = str(body.get("glimmerId", "")).strip()
    content = str(body.get("content", "")).strip()

    if not glimmer_id:
        return JSONResponse({"error": "Missing glimmerId"}, status_code=400)
    if not content:
        return JSONResponse({"error": "Missing content"}, status_code=400)

    return _compose_stream(
        request=request,
        lang=lang,
        glimmer_id=glimmer_id,
        content=content,
    )
