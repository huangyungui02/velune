from __future__ import annotations

import json
from typing import Any

from langchain_core.messages import AIMessage, ToolMessage

from app.soulers.services.resolution import resolve_or_enqueue_souler
from app.starsea.state import State

from .glimmer import create_get_glimmer_messages_tool
from .match import MATCH_TOOL_NAME, create_match_resonances_tool


def starsea_tools(
    state: State,
    *,
    memory_enabled: bool,
) -> list[Any]:
    user_id = state["metadata"]["user_id"]
    lang = state["metadata"]["lang"]
    tools = [create_match_resonances_tool(lang=lang)]
    if memory_enabled:
        tools.append(create_get_glimmer_messages_tool(user_id, lang=lang))
    return tools


async def run_starsea_tools(
    response: AIMessage,
    tools: list[Any],
    *,
    lang: str,
) -> tuple[list[ToolMessage], list[Any]]:
    tool_by_name = {tool.name: tool for tool in tools}
    tool_messages: list[ToolMessage] = []
    resonance_matches: list[Any] = []

    for tool_call in response.tool_calls:
        tool = tool_by_name[tool_call["name"]]
        args = dict(tool_call["args"])

        tool_message = await _invoke_tool(tool, tool_call, args)
        if tool.name == MATCH_TOOL_NAME:
            resonance_matches.extend(
                await _resolve_resonance_matches(tool_message, lang)
            )
        tool_messages.append(tool_message)

    return tool_messages, resonance_matches


async def _invoke_tool(
    tool: Any,
    tool_call: dict[str, Any],
    args: dict[str, Any],
) -> ToolMessage:
    try:
        return await tool.ainvoke({**tool_call, "args": args})
    except Exception as exc:
        content = {"error": f"{tool.name} failed: {exc}"}
        if tool.name == MATCH_TOOL_NAME:
            content = {"matches": [], **content}

        return ToolMessage(
            content=json.dumps(content, ensure_ascii=False),
            name=tool.name,
            tool_call_id=tool_call["id"],
        )


async def _resolve_resonance_matches(
    tool_message: ToolMessage,
    lang: str,
) -> list[dict[str, Any]]:
    resolved_matches: list[dict[str, Any]] = []
    tool_data = json.loads(tool_message.content)
    for match in tool_data["matches"]:
        name = match["name"]
        resolved: dict[str, Any]
        try:
            resolved = await resolve_or_enqueue_souler(name, lang)
        except Exception:  # noqa: BLE001
            resolved = {"status": "unavailable"}

        enriched: dict[str, Any] = {
            "name": name,
            "whisper": match["whisper"],
            "resolutionStatus": resolved.get("status") or "unavailable",
        }
        if resolved.get("soulerId"):
            enriched["soulerId"] = resolved["soulerId"]
        if resolved.get("requestId"):
            enriched["resolutionRequestId"] = resolved["requestId"]

        resolved_matches.append(enriched)

    return resolved_matches
