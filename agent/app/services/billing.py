from __future__ import annotations

import asyncio
import logging
from typing import Any, Awaitable, Callable

from app.errors import error_log_payload
from app.supabase_repo import refund_stardust

logger = logging.getLogger(__name__)

CHAT_STARDUST_COST = 1
ECHO_STARDUST_COST = 5

RunBlocking = Callable[..., Awaitable[Any]]


async def refund_stardust_safely(
    user_id: str,
    amount: int,
    *,
    reason: str,
    run_blocking: RunBlocking | None = None,
) -> None:
    if amount <= 0:
        return

    try:
        if run_blocking is None:
            await asyncio.to_thread(refund_stardust, user_id, amount)
        else:
            await run_blocking("Refund stardust", refund_stardust, user_id, amount)
    except Exception as refund_error:  # noqa: BLE001
        logger.error(
            "Failed to refund stardust: reason=%s user_id=%s amount=%s error=%s",
            reason,
            user_id,
            amount,
            error_log_payload(refund_error),
        )
