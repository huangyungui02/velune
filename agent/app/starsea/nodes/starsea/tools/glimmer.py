from __future__ import annotations

import json

from langchain_core.tools import tool

from app.starsea.repositories.glimmers import get_glimmer_messages

from ..context import format_glimmer_messages


def create_get_glimmer_messages_tool(user_id: str, timezone_name: str):
    @tool("get_glimmer_messages")
    async def get_glimmer_messages_tool(glimmer_id: str) -> str:
        """查询某个 glimmer 对应的星海聊天 messages 详情。"""
        messages = await get_glimmer_messages(user_id, glimmer_id)
        return json.dumps(
            {
                "glimmer_id": glimmer_id,
                "messages": format_glimmer_messages(messages, timezone_name),
            },
            ensure_ascii=False,
        )

    return get_glimmer_messages_tool
