from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Any

from .answer import souler_answer
from .canonical import canonicalize_souler_name
from .match import match_soulers
from app.errors import CreditLimitError
from app.repositories import (
    add_souler_alias,
    create_echo,
    create_or_update_resonance,
    create_souler,
    get_souler_by_alias,
    get_souler_by_canonical_name,
    get_souler_by_name,
)
from app.shared import Lang

ECHO_MATCH_MODEL = "qwen3.5-plus"


@dataclass
class GraphResult:
    completed: bool
    refund_credits: int


class EchoGraphFailedError(RuntimeError):
    def __init__(self, message: str, refund_credits: int) -> None:
        super().__init__(message)
        self.refund_credits = max(refund_credits, 0)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _reason_to_message(reason: Any) -> str:
    if isinstance(reason, Exception) and str(reason).strip():
        return str(reason)
    if isinstance(reason, str) and reason.strip():
        return reason
    if isinstance(reason, dict):
        for key in ("message", "error", "details", "hint"):
            value = reason.get(key)
            if isinstance(value, str) and value.strip():
                return value
    return "Unknown failure"


async def _resolve_souler(
    matched_name: str,
    lang: Lang,
) -> dict[str, Any]:
    souler_data = get_souler_by_name(matched_name, lang)
    if souler_data:
        return souler_data

    souler_data = get_souler_by_alias(matched_name, lang)
    if souler_data:
        return souler_data

    canonical_name = await canonicalize_souler_name(matched_name, lang)
    souler_data = get_souler_by_canonical_name(canonical_name, lang)
    if souler_data:
        add_souler_alias(
            str(souler_data["id"]),
            str(souler_data["name"]).strip(),
            matched_name,
            lang,
        )
        return souler_data

    try:
        return create_souler(
            matched_name,
            lang,
            canonical_name=canonical_name,
        )
    except Exception:  # noqa: BLE001
        # Concurrent requests can race while inserting the same canonical name.
        souler_data = get_souler_by_canonical_name(canonical_name, lang)
        if not souler_data:
            raise
        add_souler_alias(
            str(souler_data["id"]),
            str(souler_data["name"]).strip(),
            matched_name,
            lang,
        )
        return souler_data


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------


async def invoke_echo_graph(
    *,
    user_id: str,
    glimmer_id: str,
    glimmer_content: str,
    num: int,
    lang: Lang,
    model: str,
    on_echo: Callable[[dict[str, Any]], Awaitable[None] | None] | None = None,
) -> GraphResult:
    souler_names = await match_soulers(
        glimmer_content,
        num,
        lang,
        model=ECHO_MATCH_MODEL,
    )
    souler_names = souler_names[:num]
    missing_credits = max(num - len(souler_names), 0)

    if not souler_names:
        raise EchoGraphFailedError("Failed to match echoes", num)

    async def process_item(matched_name: str) -> None:
        souler_data = await _resolve_souler(matched_name, lang)
        souler_id = str(souler_data["id"])
        souler_name = str(souler_data["name"]).strip()

        answer = await souler_answer(
            glimmer_content,
            souler_name,
            lang,
            model=model,
        )
        echo = create_echo(glimmer_id, souler_id, answer)
        echo["souler_name"] = souler_name
        create_or_update_resonance(user_id, souler_id, None)

        if on_echo:
            maybe_awaitable = on_echo(echo)
            if asyncio.iscoroutine(maybe_awaitable):
                await maybe_awaitable

    results = await asyncio.gather(
        *(process_item(name) for name in souler_names),
        return_exceptions=True,
    )

    errors = [
        _reason_to_message(result)
        for result in results
        if isinstance(result, Exception)
    ]
    credit_errors = [
        result for result in results if isinstance(result, CreditLimitError)
    ]
    refund_credits = missing_credits + len(errors)

    if refund_credits == num:
        if credit_errors:
            raise EchoGraphFailedError(str(credit_errors[0]), refund_credits)
        raise EchoGraphFailedError(
            f"Errors when creating echoes: {' | '.join(errors)}",
            refund_credits,
        )

    return GraphResult(
        completed=refund_credits == 0,
        refund_credits=refund_credits,
    )
