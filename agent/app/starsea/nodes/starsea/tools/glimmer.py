from __future__ import annotations

import json
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from langchain_core.tools import tool

from app.starsea.repositories.glimmers import get_glimmer_messages


def create_get_glimmer_messages_tool(user_id: str, timezone_name: str):
    @tool("get_glimmer_messages")
    async def get_glimmer_messages_tool(glimmer_id: str) -> str:
        """查询某个 glimmer 对应的星海聊天 messages 详情。"""
        messages = await get_glimmer_messages(user_id, glimmer_id)
        return json.dumps(
            {
                "glimmer_id": glimmer_id,
                "messages": [
                    {
                        "id": message["id"],
                        "sequence": message["sequence"],
                        "type": message["type"],
                        "role": message["role"],
                        "content": message["content"],
                        "created_at": _format_local_datetime(
                            _parse_datetime(message["created_at"]),
                            timezone_name,
                        ),
                    }
                    for message in messages
                ],
            },
            ensure_ascii=False,
        )

    return get_glimmer_messages_tool


def _format_local_datetime(value: datetime, timezone_name: str) -> str:
    local_value = value.astimezone(ZoneInfo(timezone_name))
    return f"{local_value.isoformat()} ({timezone_name})"


def _parse_datetime(value: str) -> datetime:
    normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
    parsed = datetime.fromisoformat(normalized)
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed
