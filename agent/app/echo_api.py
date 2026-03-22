from __future__ import annotations

import asyncio
import logging
from collections.abc import Awaitable, Callable
from typing import Any

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from starlette.requests import ClientDisconnect

from app.echo_logic import Lang, invoke_echo_graph
from app.errors import CreditLimitError, credit_error_payload, error_log_payload, error_message
from app.sse import sse_event, sse_response
from app.supabase_repo import (
    ensure_glimmer,
    get_user_credit_state,
    get_user_id_from_auth_header,
    list_glimmer_echoes,
    update_glimmer_status,
)

router = APIRouter()
logger = logging.getLogger(__name__)

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


def _done_event_payload(credit_state: Any) -> dict[str, Any]:
    return {
        "type": "done",
        "creditsRemaining": credit_state.credits_remaining if credit_state else None,
        "monthlyLimit": credit_state.monthly_limit if credit_state else None,
        "plan": credit_state.plan if credit_state else None,
    }


async def _compose_worker(
    *,
    request: Request,
    lang: Lang,
    glimmer_id: str,
    content: str,
    send: Send,
) -> None:
    processing_started = False
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
            await send(_done_event_payload(get_user_credit_state(user_id)))
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

        result = await invoke_echo_graph(
            user_id=user_id,
            glimmer_id=glimmer_id,
            glimmer_content=str(glimmer.get("content", content)),
            num=5,
            lang=lang,  # type: ignore[arg-type]
            on_echo=lambda echo_row: send(_echo_event_payload(echo_row)),
        )

        update_glimmer_status(
            glimmer_id,
            "complete" if result.completed else "incomplete",
        )

        credit_state = result.credit_state
        await send(_done_event_payload(credit_state))
    except (ClientDisconnect, asyncio.CancelledError):
        if processing_started:
            _fail_glimmer_safely(glimmer_id)
        return
    except Exception as error:  # noqa: BLE001
        if processing_started:
            _fail_glimmer_safely(glimmer_id)

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
