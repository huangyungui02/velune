from __future__ import annotations

import json
import re
from typing import TYPE_CHECKING, Any

from langchain_core.messages import AIMessage, AIMessageChunk, SystemMessage, ToolMessage
from langgraph.config import get_stream_writer

from app.core.llm import create_chat_model
from app.services.starsea.messages import format_messages
from app.services.starsea.tools import match_thought_voices

from .prompt import system_prompt

if TYPE_CHECKING:
    from app.services.starsea.state import State

STARSEA_MODEL = "qwen3.5-flash"
STARSEA_TEMPERATURE = 0.5
STARSEA_TOOLS = [match_thought_voices]


def starsea_node(state: State) -> dict[str, Any]:
    lang = _state_lang(state)
    model = create_chat_model(
        model=STARSEA_MODEL,
        temperature=STARSEA_TEMPERATURE,
    ).bind_tools(STARSEA_TOOLS)
    messages = [
        SystemMessage(content=system_prompt(lang)),
        *state["messages"],
    ]
    response = _stream_ai_message(model, messages)
    returned_messages: list[Any] = [response]
    final_response = response
    resonance_matches: list[Any] = []

    if isinstance(response, AIMessage) and response.tool_calls:
        tool_messages, resonance_matches = _run_starsea_tools(response, state)
        returned_messages.extend(tool_messages)
        final_response = _stream_ai_message(model, [*messages, response, *tool_messages])
        returned_messages.append(final_response)

    return {
        "messages": returned_messages,
        "display": {
            "type": "starsea",
            "content": str(final_response.content).strip(),
            "resonance_matches": resonance_matches,
        },
        "archive_events": _archive_events(final_response.content, resonance_matches),
    }


def _archive_events(content: Any, resonance_matches: list[Any]) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    visible_reply = _strip_options_markup(str(content).strip())
    if visible_reply:
        events.append(
            {
                "type": "message",
                "role": "assistant",
                "content": visible_reply,
                "payload": {},
            }
        )

    if resonance_matches:
        events.append(
            {
                "type": "tool_result",
                "role": None,
                "content": None,
                "payload": {
                    "tool": "resonance_match",
                    "items": resonance_matches,
                },
            }
        )

    return events


def _strip_options_markup(content: str) -> str:
    return re.sub(
        r"\n*---JSON---.*?---END_JSON---\s*",
        "",
        content,
        flags=re.DOTALL,
    ).strip()


def _run_starsea_tools(
    response: AIMessage,
    state: State,
) -> tuple[list[ToolMessage], list[Any]]:
    tools_by_name = {tool.name: tool for tool in STARSEA_TOOLS}
    tool_messages: list[ToolMessage] = []
    resonance_matches: list[Any] = []
    lang = _state_lang(state)
    conversation = format_messages(state["messages"], lang)

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
        args["conversation"] = args.get("conversation") or conversation
        args["lang"] = lang
        try:
            tool_message = selected_tool.invoke({**tool_call, "args": args})
        except Exception as exc:
            tool_message = ToolMessage(
                content=json.dumps(
                    {
                        "voices": [],
                        "error": f"{selected_tool.name} failed: {exc}",
                    },
                    ensure_ascii=False,
                ),
                name=selected_tool.name,
                tool_call_id=tool_call["id"],
            )

        if selected_tool.name == match_thought_voices.name:
            tool_message, previews = _prepare_match_tool_message(tool_message)
            resonance_matches.extend(previews)
            _stream_resonance_matches(previews)

        tool_messages.append(tool_message)

    return tool_messages, resonance_matches


def _state_lang(state: State) -> str:
    return "zh" if state.get("metadata", {}).get("lang") == "zh" else "en"


def _stream_ai_message(model: Any, messages: list[Any]) -> AIMessage:
    final_chunk: AIMessageChunk | None = None
    for chunk in model.stream(messages):
        if not isinstance(chunk, AIMessageChunk):
            continue

        final_chunk = chunk if final_chunk is None else final_chunk + chunk
        _stream_message_delta(_content_text(chunk.content))

    if final_chunk is None:
        return AIMessage(content="")

    return AIMessage(
        content=final_chunk.content,
        additional_kwargs=final_chunk.additional_kwargs,
        response_metadata=final_chunk.response_metadata,
        tool_calls=final_chunk.tool_calls,
        invalid_tool_calls=final_chunk.invalid_tool_calls,
        id=final_chunk.id,
        usage_metadata=final_chunk.usage_metadata,
    )


def _prepare_match_tool_message(
    tool_message: ToolMessage,
) -> tuple[ToolMessage, list[dict[str, str]]]:
    payload = _load_tool_json(tool_message.content)
    if payload is None:
        return tool_message, []

    voices = payload.get("voices") or payload.get("matches") or []
    if not isinstance(voices, list):
        return tool_message, []

    previews: list[dict[str, str]] = []
    stripped_voices: list[dict[str, str]] = []
    for voice in voices:
        if not isinstance(voice, dict):
            continue

        name = str(voice.get("name") or "").strip()
        resonance = str(voice.get("resonance") or "").strip()
        whisper = str(voice.get("whisper") or "").strip()
        if not name:
            continue

        if name and resonance:
            stripped_voices.append({"name": name, "resonance": resonance})

        if name and whisper:
            previews.append({"name": name, "line": whisper})

    stripped_payload = {
        **payload,
        "voices": stripped_voices,
    }
    stripped_payload.pop("matches", None)

    return (
        ToolMessage(
            content=json.dumps(stripped_payload, ensure_ascii=False),
            name=tool_message.name,
            tool_call_id=tool_message.tool_call_id,
        ),
        previews,
    )


def _load_tool_json(content: Any) -> dict[str, Any] | None:
    if not isinstance(content, str):
        return None

    try:
        payload = json.loads(content)
    except json.JSONDecodeError:
        return None

    if isinstance(payload, dict):
        return payload

    return None


def _stream_resonance_matches(previews: list[dict[str, str]]) -> None:
    if not previews:
        return

    try:
        writer = get_stream_writer()
    except RuntimeError:
        return

    writer(
        {
            "type": "resonance_match",
            "matches": previews,
        }
    )


def _stream_message_delta(delta: str) -> None:
    if not delta:
        return

    try:
        writer = get_stream_writer()
    except RuntimeError:
        return

    writer(
        {
            "type": "message_delta",
            "display_type": "starsea",
            "delta": delta,
        }
    )


def _content_text(content: Any) -> str:
    if isinstance(content, str):
        return content

    if not isinstance(content, list):
        return ""

    parts: list[str] = []
    for item in content:
        if isinstance(item, str):
            parts.append(item)
        elif isinstance(item, dict):
            text = item.get("text")
            if isinstance(text, str):
                parts.append(text)

    return "".join(parts)
