from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from app.core.config import get_settings
from app.domain import CreditLimitError
from app.core.errors import error_log_payload
from app.repositories import consume_stardust, refund_stardust

logger = logging.getLogger(__name__)
settings = get_settings()

CHAT_STARDUST_COST = 1


def is_billing_enabled() -> bool:
    return bool(settings.BILLING_ENABLED)


async def consume_stardust_if_enabled(user_id: str, amount: int) -> int:
    if amount <= 0 or not is_billing_enabled():
        return 0

    await consume_stardust(user_id, amount)
    return amount


async def refund_stardust_safely(user_id: str, amount: int, *, reason: str) -> None:
    if amount <= 0 or not is_billing_enabled():
        return

    try:
        await refund_stardust(user_id, amount)
    except CreditLimitError as refund_error:
        logger.error(
            "Failed to refund stardust: reason=%s user_id=%s amount=%s error=%s",
            reason,
            user_id,
            amount,
            error_log_payload(refund_error),
        )
    except Exception as refund_error:  # noqa: BLE001
        logger.error(
            "Failed to refund stardust: reason=%s user_id=%s amount=%s error=%s",
            reason,
            user_id,
            amount,
            error_log_payload(refund_error),
        )


@asynccontextmanager
async def stardust_charge(
    user_id: str,
    amount: int,
    *,
    reason: str,
) -> AsyncIterator[None]:
    await consume_stardust_if_enabled(user_id, amount)
    try:
        yield
    except Exception:
        await refund_stardust_safely(user_id, amount, reason=reason)
        raise
