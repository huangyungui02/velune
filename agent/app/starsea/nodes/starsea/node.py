from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Any
from zoneinfo import ZoneInfo

from langchain_core.messages import AIMessage, AIMessageChunk, SystemMessage
from langgraph.config import get_stream_writer

from app.core.conversation_options import (
    ConversationOptionStreamState,
    consume_conversation_options_stream_delta,
    parse_conversation_options_response,
    strip_conversation_options_markup,
)
from app.core.llm import create_chat_model, model_for_premium
from app.starsea.repositories.glimmers import get_recent_glimmers
from app.starsea.schemas.archive import ResonanceMatchArchive, TextArchive
from app.starsea.schemas.events import DeltaEvent, OptionEvent, ResonanceMatchEvent
from app.starsea.schemas.model import DeltaContent, OptionContent, ResonanceMatchContent

from .prompt import system_prompt
from .tools import run_starsea_tools, starsea_tools

if TYPE_CHECKING:
    from app.starsea.state import ArchiveState, State

STARSEA_TEMPERATURE = 0.5


async def starsea_node(state: State) -> dict[str, Any]:
    lang = state["metadata"]["lang"]
    timezone_name = state["metadata"]["timezone"]
    memory_enabled = state["metadata"]["memory_enabled"]
    recent_glimmers = (
        await get_recent_glimmers(state["metadata"]["user_id"], limit=5)
        if memory_enabled
        else []
    )
    current_time = (
        datetime.now(timezone.utc)
        .astimezone(ZoneInfo(timezone_name))
        .isoformat()
    )
    recent_glimmers_context = None
    if memory_enabled:
        recent_glimmers_context = "\n".join(
            json.dumps(
                {
                    "id": glimmer["id"],
                    "content": glimmer["content"],
                    "created_at": _local_datetime_string(
                        glimmer["created_at"],
                        timezone_name,
                    ),
                },
                ensure_ascii=False,
            )
            for glimmer in recent_glimmers
        )

    tools = starsea_tools(state, memory_enabled=memory_enabled)
    starsea_model = model_for_premium(state["metadata"]["is_premium"])
    model = create_chat_model(
        model=starsea_model,
        temperature=STARSEA_TEMPERATURE,
    ).bind_tools(tools)
    reply_model = create_chat_model(
        model=starsea_model,
        temperature=STARSEA_TEMPERATURE,
    )
    messages = [
        SystemMessage(
            content=system_prompt(
                lang,
                current_time=current_time,
                recent_glimmers=recent_glimmers_context,
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
        final_response = await _stream_ai_message(
            reply_model,
            [*messages, response, *tool_messages],
        )
        returned_messages.append(final_response)

    _stream_conversation_options(final_response.content)

    return {
        "messages": returned_messages,
        "archives": _archives(
            response.content if resonance_matches else None,
            resonance_matches,
            final_response.content,
        ),
    }


def _archives(
    before_matches_content: Any,
    resonance_matches: list[Any],
    after_matches_content: Any,
) -> list[ArchiveState]:
    events: list[ArchiveState] = []
    _append_visible_message(events, before_matches_content)

    if resonance_matches:
        events.append(
            ResonanceMatchArchive(content=resonance_matches).model_dump(
                mode="json",
                by_alias=True,
                exclude_none=True,
            )
        )

    _append_visible_message(events, after_matches_content)

    return events


def _append_visible_message(events: list[ArchiveState], content: Any) -> None:
    visible_reply = strip_conversation_options_markup(str(content or "").strip())
    if not visible_reply:
        return

    events.append(TextArchive(role="assistant", content=visible_reply).model_dump(mode="json"))


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

    content = ResonanceMatchContent(matches=previews)
    get_stream_writer()(ResonanceMatchEvent(content=content))


def _stream_conversation_options(content: Any) -> None:
    try:
        _, options = parse_conversation_options_response(_content_text(content))
    except ValueError:
        return

    option_content = OptionContent(options=options)
    get_stream_writer()(OptionEvent(content=option_content))


def _stream_message_delta(delta: str) -> None:
    if not delta:
        return

    content = DeltaContent(delta=delta, display_type="starsea")
    get_stream_writer()(DeltaEvent(content=content))


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


def _local_datetime_string(value: str, timezone_name: str) -> str:
    normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
    parsed = datetime.fromisoformat(normalized)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(ZoneInfo(timezone_name)).isoformat()
