from __future__ import annotations

import asyncio
import contextlib
import logging

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse, StreamingResponse
from starlette.requests import ClientDisconnect

from app.echo_logic import Lang, invoke_echo_graph
from app.errors import CreditLimitError, credit_error_payload, error_log_payload, error_message
from app.sse import sse_event, sse_response
from app.supabase_repo import (
    check_status_before_processing,
    get_glimmer,
    get_user_id_from_auth_header,
    update_glimmer_status,
)

router = APIRouter()
logger = logging.getLogger(__name__)


def _fail_glimmer_safely(glimmer_id: str) -> None:
    try:
        update_glimmer_status(glimmer_id, "failed")
    except Exception:  # noqa: BLE001
        pass


@router.post("/{lang}/echo")
async def echo(lang: Lang, request: Request):
    try:
        body = await request.json()
    except Exception:  # noqa: BLE001
        return JSONResponse({"error": "Invalid JSON body"}, status_code=400)

    glimmer_id = str(body.get("glimmerId", "")).strip()

    if not glimmer_id:
        return JSONResponse({"error": "Missing glimmerId"}, status_code=400)

    async def event_stream():
        queue: asyncio.Queue[dict | None] = asyncio.Queue()

        async def send(payload: dict) -> None:
            await queue.put(payload)

        async def worker() -> None:
            processing_started = False
            try:
                user_id = get_user_id_from_auth_header(request.headers.get("Authorization"))
                glimmer = get_glimmer(glimmer_id, user_id)

                check_status_before_processing(glimmer_id)
                update_glimmer_status(glimmer_id, "processing")
                processing_started = True

                result = await invoke_echo_graph(
                    user_id=user_id,
                    glimmer_id=glimmer_id,
                    glimmer_content=str(glimmer.get("content", "")),
                    num=5,
                    lang=lang,  # type: ignore[arg-type]
                    on_echo=lambda echo_row: send(
                        {
                            "type": "echo",
                            "echo": {
                                "id": echo_row.get("id"),
                                "glimmerId": echo_row.get("glimmer_id"),
                                "soulerId": echo_row.get("souler_id"),
                                "soulerName": echo_row.get("souler_name"),
                                "sessionId": echo_row.get("session_id"),
                                "content": echo_row.get("content"),
                            },
                        }
                    ),
                )

                update_glimmer_status(
                    glimmer_id,
                    "complete" if result.completed else "incomplete",
                )

                credit_state = result.credit_state
                await send(
                    {
                        "type": "done",
                        "creditsRemaining": credit_state.credits_remaining if credit_state else None,
                        "monthlyLimit": credit_state.monthly_limit if credit_state else None,
                        "plan": credit_state.plan if credit_state else None,
                    }
                )
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
                        "Failed to process glimmer %s: %s",
                        glimmer_id,
                        error_log_payload(error),
                    )
                    await send(
                        {
                            "type": "error",
                            "message": error_message(error),
                        }
                    )
            finally:
                await queue.put(None)

        worker_task = asyncio.create_task(worker())
        try:
            while True:
                payload = await queue.get()
                if payload is None:
                    break
                yield sse_event(payload)
        except (ClientDisconnect, asyncio.CancelledError):
            worker_task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await worker_task
            return

        await worker_task

    return sse_response(event_stream())
