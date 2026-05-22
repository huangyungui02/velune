from __future__ import annotations

from app.domain import CreditLimitError

from .database import fetch_one


async def consume_stardust(user_id: str, amount: int) -> None:
    row = await fetch_one(
        """
        SELECT ok, code, message, credits, product_id, daily_credits
        FROM public.consume_stardust(CAST(:user_id AS uuid), :amount)
        """,
        {"user_id": user_id, "amount": amount},
    )
    if not row:
        raise ValueError("Failed to consume stardust")

    if bool(row.get("ok")):
        return

    message = str(row.get("message", "Not enough credits for this request"))
    code = str(row.get("code", "INSUFFICIENT_CREDITS"))
    raise CreditLimitError(message, code)


async def refund_stardust(user_id: str, amount: int) -> None:
    row = await fetch_one(
        """
        SELECT ok, code, message, credits, product_id, daily_credits
        FROM public.refund_stardust(CAST(:user_id AS uuid), :amount)
        """,
        {"user_id": user_id, "amount": amount},
    )
    if not row:
        raise ValueError("Failed to refund stardust")

    if bool(row.get("ok")):
        return

    message = str(row.get("message", "Not enough credits for this request"))
    code = str(row.get("code", "INSUFFICIENT_CREDITS"))
    raise CreditLimitError(message, code)
