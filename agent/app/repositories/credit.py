from __future__ import annotations

from typing import Any

from app.errors import CreditLimitError

from ._client import first_row, supabase


def _parse_credit_consumption_row(row: dict[str, Any]) -> None:
    ok = bool(row.get("ok"))
    if ok:
        return

    message = str(row.get("message", "Not enough credits for this request"))
    code = str(row.get("code", "INSUFFICIENT_CREDITS"))
    raise CreditLimitError(message, code)


def _consume_credit_rpc(
    rpc_name: str,
    payload: dict[str, Any],
    *,
    missing_row_error: str,
) -> None:
    response = supabase.rpc(rpc_name, payload).execute()
    row = first_row(response.data)
    if not row:
        raise ValueError(missing_row_error)
    _parse_credit_consumption_row(row)


def consume_stardust(user_id: str, amount: int) -> None:
    _consume_credit_rpc(
        "consume_stardust",
        payload={
            "p_user_id": user_id,
            "p_cost": amount,
        },
        missing_row_error="Failed to consume stardust",
    )


def consume_echo_credit(user_id: str, amount: int = 5) -> None:
    _consume_credit_rpc(
        "consume_stardust",
        payload={
            "p_user_id": user_id,
            "p_cost": amount,
        },
        missing_row_error="Failed to consume echo credit",
    )


def consume_chat_credit(user_id: str) -> None:
    _consume_credit_rpc(
        "consume_chat_credit",
        payload={
            "p_user_id": user_id,
        },
        missing_row_error="Failed to consume chat credit",
    )


def refund_stardust(user_id: str, amount: int) -> None:
    _consume_credit_rpc(
        "refund_stardust",
        payload={
            "p_user_id": user_id,
            "p_amount": amount,
        },
        missing_row_error="Failed to refund stardust",
    )
