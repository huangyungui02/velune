from __future__ import annotations

import json
from typing import TYPE_CHECKING, Any

from langchain_core.messages import AIMessage, ToolMessage

from app.soulers.services.resolution import resolve_or_enqueue_souler
from app.starsea.messages import format_messages

from .glimmer import create_get_glimmer_messages_tool
from .match import match_resonances

if TYPE_CHECKING:
    from app.starsea.state import State


def starsea_tools(
    state: State,
    timezone_name: str,
    *,
    memory_enabled: bool = False,
) -> list[Any]:
    user_id = state["metadata"]["user_id"]
    tools = [match_resonances]
    if memory_enabled:
        tools.append(create_get_glimmer_messages_tool(user_id, timezone_name))
    return tools


async def run_starsea_tools(
    response: AIMessage,
    state: State,
    tools: list[Any],
    *,
    lang: str,
) -> tuple[list[ToolMessage], list[Any]]:
    tools_by_name = {tool.name: tool for tool in tools}
    tool_messages: list[ToolMessage] = []
    resonance_matches: list[Any] = []
    context = format_messages(state["messages"], lang)

    for tool_call in response.tool_calls:
        selected_tool = tools_by_name.get(tool_call["name"])
        if selected_tool is None:
            tool_messages.append(
                ToolMessage(
                    content=f"Unknown tool: {tool_call['name']}",
                    tool_call_id=tool_call["id"],
                )
            )
            continue

        args = dict(tool_call.get("args") or {})
        if selected_tool.name == match_resonances.name:
            args["context"] = context
            args["lang"] = lang
        try:
            tool_message = await selected_tool.ainvoke({**tool_call, "args": args})
        except Exception as exc:
            error_content = {"error": f"{selected_tool.name} failed: {exc}"}
            print(f"error_content: {error_content}")
            if selected_tool.name == match_resonances.name:
                error_content = {"matches": [], **error_content}
            tool_message = ToolMessage(
                content=json.dumps(error_content, ensure_ascii=False),
                name=selected_tool.name,
                tool_call_id=tool_call["id"],
            )

        if selected_tool.name == match_resonances.name:
            tool_message, previews = _prepare_match_tool_message(tool_message)
            resolved_previews = await _resolve_match_previews(previews, lang)
            resonance_matches.extend(resolved_previews)

        tool_messages.append(tool_message)

    return tool_messages, resonance_matches


async def _resolve_match_previews(
    previews: list[dict[str, str]],
    lang: str,
) -> list[dict[str, Any]]:
    resolved_previews: list[dict[str, Any]] = []
    for preview in previews:
        name = preview["name"]
        resolved: dict[str, Any]
        try:
            resolved = await resolve_or_enqueue_souler(name, lang)
        except Exception:  # noqa: BLE001
            resolved = {"status": "unavailable"}

        enriched: dict[str, Any] = {
            "name": name,
            "line": preview["line"],
            "resolutionStatus": resolved.get("status") or "unavailable",
        }
        if resolved.get("soulerId"):
            enriched["soulerId"] = resolved["soulerId"]
        if resolved.get("requestId"):
            enriched["resolutionRequestId"] = resolved["requestId"]

        resolved_previews.append(enriched)

    return resolved_previews


def _prepare_match_tool_message(
    tool_message: ToolMessage,
) -> tuple[ToolMessage, list[dict[str, str]]]:
    tool_data = _load_tool_json(tool_message.content)
    if tool_data is None:
        return tool_message, []

    matches = tool_data.get("matches") or []
    if not isinstance(matches, list):
        return tool_message, []

    previews: list[dict[str, str]] = []
    stripped_matches: list[dict[str, str]] = []
    for match in matches:
        if not isinstance(match, dict):
            continue

        name = str(match.get("name") or "").strip()
        resonance = str(match.get("resonance") or "").strip()
        whisper = str(match.get("whisper") or "").strip()
        if not name:
            continue

        if name and resonance:
            stripped_matches.append({"name": name, "resonance": resonance})

        if name and whisper:
            previews.append({"name": name, "line": whisper})

    stripped_data = {
        **tool_data,
        "matches": stripped_matches,
    }

    return (
        ToolMessage(
            content=json.dumps(stripped_data, ensure_ascii=False),
            name=tool_message.name,
            tool_call_id=tool_message.tool_call_id,
        ),
        previews,
    )


def _load_tool_json(content: Any) -> dict[str, Any] | None:
    if not isinstance(content, str):
        return None

    try:
        tool_data = json.loads(content)
    except json.JSONDecodeError:
        return None

    if isinstance(tool_data, dict):
        return tool_data

    return None
