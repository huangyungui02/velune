from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Any

from app.echo_nodes import (
    Lang,
    generate_souler_aliases,
    match_soulers,
    session_title,
    souler_answer,
    souler_profile,
    souler_prompt,
)
from app.errors import CreditLimitError, CreditState
from app.supabase_repo import (
    append_souler_alias,
    consume_user_credit,
    create_echo,
    create_or_update_resonance,
    create_session,
    create_souler,
    get_souler_by_alias,
    insert_session_message,
    update_souler,
)


@dataclass
class GraphResult:
    completed: bool
    credit_state: CreditState | None


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


async def invoke_echo_graph(
    *,
    user_id: str,
    glimmer_id: str,
    glimmer_content: str,
    num: int,
    lang: Lang,
    on_echo: Callable[[dict[str, Any]], Awaitable[None] | None] | None = None,
) -> GraphResult:
    soulers = await match_soulers(glimmer_content, num, lang)

    async def process_item(item: dict[str, str]) -> CreditState:
        matched_name = item.get("souler", "").strip()
        if not matched_name:
            raise ValueError("Matched souler name cannot be empty")

        souler_data = get_souler_by_alias(matched_name)
        if not souler_data:
            aliases = await generate_souler_aliases(matched_name, lang)
            souler_data = create_souler(matched_name, aliases)
        else:
            souler_data = append_souler_alias(str(souler_data["id"]), matched_name)

        bio = souler_data.get("bio")
        if not isinstance(bio, str) or not bio.strip():
            generated_bio = await souler_profile(str(souler_data["name"]), lang)
            souler_data["bio"] = generated_bio
            update_souler(str(souler_data["id"]), {"bio": generated_bio})

        prompt = souler_data.get("prompt")
        if not isinstance(prompt, str) or not prompt.strip():
            generated_prompt = await souler_prompt(str(souler_data["name"]), lang)
            souler_data["prompt"] = generated_prompt
            update_souler(str(souler_data["id"]), {"prompt": generated_prompt})

        credit_state = consume_user_credit(user_id)
        answer = await souler_answer(
            glimmer_content,
            str(souler_data["prompt"]),
            lang,
        )
        title = await session_title(glimmer_content, answer, lang)

        session_id = create_session(
            user_id,
            str(souler_data["id"]),
            title,
        )

        insert_session_message(
            user_id,
            str(souler_data["id"]),
            session_id,
            "user",
            glimmer_content,
        )
        insert_session_message(
            user_id,
            str(souler_data["id"]),
            session_id,
            "assistant",
            answer,
        )

        echo = create_echo(
            glimmer_id,
            str(souler_data["id"]),
            answer,
            session_id,
        )
        echo["souler_name"] = str(souler_data.get("name", "")).strip()
        create_or_update_resonance(user_id, str(souler_data["id"]))

        if on_echo:
            maybe_awaitable = on_echo(echo)
            if asyncio.iscoroutine(maybe_awaitable):
                await maybe_awaitable

        return credit_state

    results = await asyncio.gather(
        *(process_item(item) for item in soulers),
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
