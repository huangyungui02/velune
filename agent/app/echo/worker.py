from __future__ import annotations

import asyncio
import logging
from collections.abc import Awaitable, Callable
from typing import Any

from starlette.requests import ClientDisconnect

from app.billing import ECHO_STARDUST_COST, refund_stardust_safely
from app.echo.graph import EchoGraphFailedError, invoke_echo_graph
from app.errors import CreditLimitError, credit_error_payload, error_log_payload, error_message
from app.repositories import (
    consume_stardust,
    ensure_glimmer,
    list_glimmer_echoes,
    update_glimmer_status,
)
from app.shared import Lang

logger = logging.getLogger(__name__)

ECHO_MODEL = "qwen3.5-flash"
type Send = Callable[[dict[str, Any]], Awaitable[None]]


def _fail_glimmer_safely(glimmer_id: str) -> None:
    try:
        update_glimmer_status(glimmer_id, "failed")
    except Exception:  # noqa: BLE001
        pass


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


async def compose_worker(
    *,
    user_id: str,
    lang: Lang,
    glimmer_id: str,
    content: str,
    send: Send,
) -> None:
    processing_started = False
    generation_finished = False
    charged_credits = 0
    try:
        glimmer = ensure_glimmer(user_id, glimmer_id, content)
        status = str(glimmer.get("status", "pending"))

        await send(
            {
                "type": "ready",
                "glimmerId": glimmer_id,
                "status": status,
            }
        )

        replayed = 0
        for row in list_glimmer_echoes(glimmer_id):
            await send(_echo_event_payload(row))
            replayed += 1
        if replayed > 0 or status in {"complete", "incomplete"}:
            await send({"type": "done"})
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
        consume_stardust(user_id, ECHO_STARDUST_COST)
        charged_credits = ECHO_STARDUST_COST

        result = await invoke_echo_graph(
            user_id=user_id,
            glimmer_id=glimmer_id,
            glimmer_content=str(glimmer.get("content", content)),
            num=ECHO_STARDUST_COST,
            lang=lang,
            model=ECHO_MODEL,
            on_echo=lambda echo_row: send(_echo_event_payload(echo_row)),
        )
        generation_finished = True

        await refund_stardust_safely(
            user_id,
            result.refund_credits,
            reason=f"partial echo failure for glimmer {glimmer_id}",
        )

        update_glimmer_status(
            glimmer_id,
            "complete" if result.completed else "incomplete",
        )

        await send({"type": "done"})
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
            await refund_stardust_safely(
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
