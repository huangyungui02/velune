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
from app.supabase_repo import (
    add_souler_alias,
    consume_echo_credit,
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
    if not souler_names:
        return GraphResult(completed=True)

    consume_echo_credit(user_id)

    async def process_item(matched_name: str) -> None:
        souler_data = await _resolve_souler(matched_name, lang)
        souler_data = await _ensure_souler_assets(souler_data, lang)
        souler_id = _souler_id(souler_data)
        souler_name = _souler_name(souler_data)

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

    results = await asyncio.gather(
        *(process_item(name) for name in souler_names),
        return_exceptions=True,
    )

    errors = [
        _reason_to_message(result)
        for result in results
        if isinstance(result, Exception)
    ]

    if len(errors) == len(souler_names):
        raise RuntimeError(f"Errors when creating echoes: {' | '.join(errors)}")

    return GraphResult(completed=not errors)
