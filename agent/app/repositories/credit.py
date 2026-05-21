from __future__ import annotations

from app.domain.exceptions import CreditLimitError

from ._client import first_row, supabase


def consume_stardust(user_id: str, amount: int) -> None:
    response = supabase.rpc(
        "consume_stardust",
        {
            "p_user_id": user_id,
            "p_cost": amount,
        },
    ).execute()
    row = first_row(response.data)
    if not row:
        raise ValueError("Failed to consume stardust")

    if bool(row.get("ok")):
        return

    message = str(row.get("message", "Not enough credits for this request"))
    code = str(row.get("code", "INSUFFICIENT_CREDITS"))
    raise CreditLimitError(message, code)


def refund_stardust(user_id: str, amount: int) -> None:
    response = supabase.rpc(
        "refund_stardust",
        {
            "p_user_id": user_id,
            "p_amount": amount,
        },
    ).execute()
    row = first_row(response.data)
    if not row:
        raise ValueError("Failed to refund stardust")

    if bool(row.get("ok")):
        return

    message = str(row.get("message", "Not enough credits for this request"))
    code = str(row.get("code", "INSUFFICIENT_CREDITS"))
    raise CreditLimitError(message, code)
