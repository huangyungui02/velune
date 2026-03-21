from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Any

from app.echo_nodes import (
    Lang,
    match_soulers,
    resolve_souler_name,
    souler_answer,
    souler_profile,
    souler_prompt,
)
from app.errors import CreditLimitError, CreditState
from app.supabase_repo import (
    add_souler_alias,
    consume_user_credit,
    create_echo,
    create_or_update_resonance,
    create_souler,
    get_souler_by_alias,
    get_souler_by_name,
    update_souler,
)


@dataclass
class GraphResult:
    completed: bool
    credit_state: CreditState | None


def _souler_id(souler_data: dict[str, Any]) -> str:
    return str(souler_data["id"])


def _souler_name(souler_data: dict[str, Any]) -> str:
    return str(souler_data["name"]).strip()


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


async def _resolve_souler(matched_name: str, lang: Lang) -> dict[str, Any]:
    souler_data = get_souler_by_alias(matched_name)
    if souler_data:
        return souler_data

    souler_data = get_souler_by_name(matched_name)
    if souler_data:
        return souler_data

    resolved_name = await resolve_souler_name(matched_name, lang)
    souler_data = get_souler_by_name(resolved_name)
    if not souler_data:
        souler_data = create_souler(resolved_name)

    add_souler_alias(_souler_id(souler_data), _souler_name(souler_data), matched_name)
    return souler_data


async def _ensure_souler_assets(
    souler_data: dict[str, Any], lang: Lang
) -> dict[str, Any]:
    souler_id = _souler_id(souler_data)
    souler_name = _souler_name(souler_data)

    bio = souler_data.get("bio")
    if not isinstance(bio, str) or not bio.strip():
        generated_bio = await souler_profile(souler_name, lang)
        souler_data["bio"] = generated_bio
        update_souler(souler_id, {"bio": generated_bio})

    prompt = souler_data.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip():
        generated_prompt = await souler_prompt(souler_name, lang)
        souler_data["prompt"] = generated_prompt
        update_souler(souler_id, {"prompt": generated_prompt})

    return souler_data


async def invoke_echo_graph(
    *,
    user_id: str,
    glimmer_id: str,
    glimmer_content: str,
    num: int,
    lang: Lang,
    on_echo: Callable[[dict[str, Any]], Awaitable[None] | None] | None = None,
) -> GraphResult:
    souler_names = await match_soulers(glimmer_content, num, lang)

    async def process_item(matched_name: str) -> CreditState:

        souler_data = await _resolve_souler(matched_name, lang)
        souler_data = await _ensure_souler_assets(souler_data, lang)
        souler_id = _souler_id(souler_data)
        souler_name = _souler_name(souler_data)

        credit_state = consume_user_credit(user_id)
        answer = await souler_answer(
            glimmer_content,
            str(souler_data["prompt"]),
            lang,
        )

        echo = create_echo(
            glimmer_id,
            souler_id,
            answer,
        )
        echo["souler_name"] = souler_name
        create_or_update_resonance(
            user_id,
            souler_id,
            None,
            "",
        )

        if on_echo:
            maybe_awaitable = on_echo(echo)
            if asyncio.iscoroutine(maybe_awaitable):
                await maybe_awaitable

        return credit_state

    results = await asyncio.gather(
        *(process_item(name) for name in souler_names),
        return_exceptions=True,
    )

    errors: list[str] = []
    first_credit_limit_error: CreditLimitError | None = None
    final_credit_state: CreditState | None = None
    completed = True

    for result in results:
        if isinstance(result, Exception):
            errors.append(_reason_to_message(result))
            if not first_credit_limit_error and isinstance(result, CreditLimitError):
                first_credit_limit_error = result
            continue

        if not final_credit_state:
            final_credit_state = result
            continue

        final_credit_state = CreditState(
            plan=result.plan,
            monthly_limit=result.monthly_limit,
            credits_remaining=min(
                final_credit_state.credits_remaining,
                result.credits_remaining,
            ),
        )

    if len(errors) == num:
        if first_credit_limit_error:
            raise first_credit_limit_error
        raise RuntimeError(f"Errors when creating echoes: {' | '.join(errors)}")

    if errors:
        completed = False

    return GraphResult(
        completed=completed,
        credit_state=final_credit_state,
    )
