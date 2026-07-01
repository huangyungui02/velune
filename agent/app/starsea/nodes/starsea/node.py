from __future__ import annotations

from typing import TYPE_CHECKING, Any

from langchain_core.messages import AIMessage, AIMessageChunk, SystemMessage
from langgraph.config import get_stream_writer

from app.core.conversation_options import (
    ConversationOptionStreamState,
    consume_conversation_options_stream_delta,
    parse_conversation_options_response,
    strip_conversation_options_markup,
)
from app.core.llm import DEFAULT_MODEL, create_chat_model

from .context import (
    current_time_context,
    format_recent_glimmers,
    state_memory_enabled,
    state_recent_glimmers,
    state_timezone,
)
from .prompt import system_prompt
from .tools import run_starsea_tools, starsea_tools

if TYPE_CHECKING:
    from app.starsea.state import State

STARSEA_MODEL = DEFAULT_MODEL
STARSEA_TEMPERATURE = 0.5


async def starsea_node(state: State) -> dict[str, Any]:
    lang = state["metadata"]["lang"]
    timezone_name = await state_timezone(state)
    memory_enabled = state_memory_enabled(state)
    recent_glimmers = await state_recent_glimmers(state) if memory_enabled else []
    tools = starsea_tools(state, timezone_name, memory_enabled=memory_enabled)
    model = create_chat_model(
        model=STARSEA_MODEL,
        temperature=STARSEA_TEMPERATURE,
    ).bind_tools(tools)
    reply_model = create_chat_model(
        model=STARSEA_MODEL,
        temperature=STARSEA_TEMPERATURE,
    )
    messages = [
        SystemMessage(
            content=system_prompt(
                lang,
                current_time=current_time_context(timezone_name),
                recent_glimmers=(
                    format_recent_glimmers(recent_glimmers, timezone_name)
                    if memory_enabled
                    else None
                ),
            )
        ),
        *state["messages"],
    ]
    response = await _stream_ai_message(model, messages)
    returned_messages: list[Any] = [response]
    final_response = response
    resonance_matches: list[Any] = []

    if isinstance(response, AIMessage) and response.tool_calls:
        tool_messages, resonance_matches = await run_starsea_tools(
            response,
            state,
            tools,
            lang=lang,
        )
        returned_messages.extend(tool_messages)
        _stream_resonance_matches(resonance_matches)
        final_response = await _stream_ai_message(reply_model, [*messages, response, *tool_messages])
        returned_messages.append(final_response)

    _stream_conversation_options(final_response.content)

    return {
        "messages": returned_messages,
        "archive_events": _archive_events(
            response.content if resonance_matches else None,
            resonance_matches,
            final_response.content,
        ),
    }


def _archive_events(
    before_matches_content: Any,
    resonance_matches: list[Any],
    after_matches_content: Any,
) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    _append_visible_message(events, before_matches_content)

    if resonance_matches:
        events.append(
            {
                "type": "resonance_match",
                "role": "assistant",
                "content": resonance_matches,
            }
        )

    _append_visible_message(events, after_matches_content)

    return events


def _append_visible_message(events: list[dict[str, Any]], content: Any) -> None:
    visible_reply = strip_conversation_options_markup(str(content or "").strip())
    if not visible_reply:
        return

    events.append(
        {
            "type": "message",
            "role": "assistant",
            "content": visible_reply,
        }
    )


async def _stream_ai_message(model: Any, messages: list[Any]) -> AIMessage:
    final_chunk: AIMessageChunk | None = None
    option_state = ConversationOptionStreamState(
        raw_chunks=[],
        output_chunks=[],
        pending="",
        phase="streaming_content",
    )
    async for chunk in model.astream(messages):
        if not isinstance(chunk, AIMessageChunk):
            continue

        final_chunk = chunk if final_chunk is None else final_chunk + chunk
        visible_delta = consume_conversation_options_stream_delta(
            option_state,
            _content_text(chunk.content),
        )
        _stream_message_delta(visible_delta)

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


def _stream_resonance_matches(previews: list[Any]) -> None:
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


def _stream_conversation_options(content: Any) -> None:
    try:
        _, options = parse_conversation_options_response(_content_text(content))
    except ValueError:
        return

    try:
        writer = get_stream_writer()
    except RuntimeError:
        return

    writer(
        {
            "type": "conversation_options",
            "options": options,
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
