from __future__ import annotations

from app.domain import CreditLimitError

from ._client import await_repo, first_row, get_supabase


async def consume_stardust(user_id: str, amount: int) -> None:
    response = await await_repo(
        get_supabase().rpc(
            "consume_stardust",
            {
                "p_user_id": user_id,
                "p_cost": amount,
            },
        ).execute()
    )
    row = first_row(response.data)
    if not row:
        raise ValueError("Failed to consume stardust")

    if bool(row.get("ok")):
        return

    message = str(row.get("message", "Not enough credits for this request"))
    code = str(row.get("code", "INSUFFICIENT_CREDITS"))
    raise CreditLimitError(message, code)


async def refund_stardust(user_id: str, amount: int) -> None:
    response = await await_repo(
        get_supabase().rpc(
            "refund_stardust",
            {
                "p_user_id": user_id,
                "p_amount": amount,
            },
        ).execute()
    )
    row = first_row(response.data)
    if not row:
        raise ValueError("Failed to refund stardust")

    if bool(row.get("ok")):
        return

    message = str(row.get("message", "Not enough credits for this request"))
    code = str(row.get("code", "INSUFFICIENT_CREDITS"))
    raise CreditLimitError(message, code)
