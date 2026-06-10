from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from app.starsea.repositories.glimmers import Glimmer, GlimmerMessage, get_recent_glimmers
from app.starsea.repositories.user_status import get_user_timezone

if TYPE_CHECKING:
    from app.starsea.state import State


async def state_timezone(state: State) -> str:
    metadata = state.get("metadata", {})
    timezone_name = _metadata_timezone(metadata)
    if timezone_name:
        return timezone_name

    user_id = str(metadata.get("user_id") or "").strip()
    if user_id:
        try:
            stored_timezone = await get_user_timezone(user_id)
        except Exception:  # noqa: BLE001
            stored_timezone = None
        timezone_name = _valid_timezone(stored_timezone)
        if timezone_name:
            return timezone_name

    return "UTC"


async def state_recent_glimmers(state: State) -> list[Glimmer]:
    user_id = str(state.get("metadata", {}).get("user_id") or "").strip()
    if not user_id:
        return []

    try:
        return await get_recent_glimmers(user_id, limit=5)
    except Exception:  # noqa: BLE001
        return []


def state_memory_enabled(state: State) -> bool:
    return state.get("metadata", {}).get("memoryEnabled") is True


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
            "payload": message["payload"],
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


def _metadata_timezone(metadata: dict[str, Any]) -> str | None:
    for key in ("timezone", "timeZone", "tz"):
        timezone_name = _valid_timezone(metadata.get(key))
        if timezone_name:
            return timezone_name
    return None


def _valid_timezone(value: Any) -> str | None:
    timezone_name = str(value or "").strip()
    if not timezone_name or timezone_name.lower() == "unknown":
        return None

    try:
        ZoneInfo(timezone_name)
    except ZoneInfoNotFoundError:
        return None
    return timezone_name


def _truthy(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, int | float):
        return value != 0
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on"}
    return False


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
