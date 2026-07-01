from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Any
from zoneinfo import ZoneInfo

from app.starsea.repositories.glimmers import Glimmer, GlimmerMessage, get_recent_glimmers

if TYPE_CHECKING:
    from app.starsea.state import State


async def state_timezone(state: State) -> str:
    return state["metadata"]["timezone"]


async def state_recent_glimmers(state: State) -> list[Glimmer]:
    try:
        return await get_recent_glimmers(state["metadata"]["user_id"], limit=5)
    except Exception:  # noqa: BLE001
        return []


def state_memory_enabled(state: State) -> bool:
    return state["metadata"]["memory_enabled"] is True


def current_time_context(timezone_name: str) -> str:
    return format_local_datetime(datetime.now(timezone.utc), timezone_name)


def format_recent_glimmers(glimmers: list[Glimmer], timezone_name: str) -> str:
    lines: list[str] = []
    for glimmer in glimmers[:5]:
        lines.append(
            json.dumps(
                {
                    "id": glimmer["id"],
                    "content": glimmer["content"],
                    "created_at": format_local_datetime(
                        _parse_datetime(glimmer["created_at"]),
                        timezone_name,
                    ),
                },
                ensure_ascii=False,
            )
        )
    return "\n".join(lines)


def format_glimmer_messages(
    messages: list[GlimmerMessage],
    timezone_name: str,
) -> list[dict[str, Any]]:
    return [
        {
            "id": message["id"],
            "sequence": message["sequence"],
            "type": message["type"],
            "role": message["role"],
            "content": message["content"],
            "created_at": format_local_datetime(
                _parse_datetime(message["created_at"]),
                timezone_name,
            ),
        }
        for message in messages
    ]


def format_local_datetime(value: datetime, timezone_name: str) -> str:
    local_value = value.astimezone(ZoneInfo(timezone_name))
    return f"{local_value.isoformat()} ({timezone_name})"


def _parse_datetime(value: str) -> datetime:
    normalized = value.strip()
    if normalized.endswith("Z"):
        normalized = f"{normalized[:-1]}+00:00"
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError:
        return datetime.now(timezone.utc)
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed
