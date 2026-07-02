from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any
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
from app.starsea.state import ArchiveState, State

from .prompt import system_prompt
from .tools import run_starsea_tools, starsea_tools

STARSEA_TEMPERATURE = 0.5


async def starsea_node(state: State) -> dict[str, Any]:
    metadata = state["metadata"]
    lang = metadata["lang"]
    tools = starsea_tools(state, memory_enabled=metadata["memory_enabled"])
    chat_model = model_for_premium(metadata["is_premium"])
    prompt_messages = [
        SystemMessage(content=await _build_system_prompt(state)),
        *state["messages"],
    ]

    first_reply = await _stream_ai_message(
        create_chat_model(
            model=chat_model,
            temperature=STARSEA_TEMPERATURE,
        ).bind_tools(tools),
        prompt_messages,
    )
    messages: list[Any] = [first_reply]
    archives: list[ArchiveState] = []
    if text := _visible_text(first_reply):
        archives.append(
            TextArchive(role="assistant", content=text).model_dump(mode="json")
        )
    last_reply = first_reply
    resonance_matches: list[Any] = []

    if first_reply.tool_calls:
        tool_messages, resonance_matches = await run_starsea_tools(
            first_reply,
            tools,
            lang=lang,
        )
        messages.extend(tool_messages)
        _stream_resonance_matches(resonance_matches)
        if resonance_matches:
            archives.append(
                ResonanceMatchArchive(content=resonance_matches).model_dump(
                    mode="json",
                    by_alias=True,
                    exclude_none=True,
                )
            )

        # The first reply decides which tools to call; this second reply turns
        # their results into user-facing prose without exposing raw tool JSON.
        final_reply = await _stream_ai_message(
            create_chat_model(
                model=chat_model,
                temperature=STARSEA_TEMPERATURE,
            ),
            [*prompt_messages, first_reply, *tool_messages],
        )
        messages.append(final_reply)
        if text := _visible_text(final_reply):
            archives.append(
                TextArchive(role="assistant", content=text).model_dump(mode="json")
            )
        last_reply = final_reply

    _stream_conversation_options(last_reply.content)

    return {
        "messages": messages,
        "archives": archives,
    }


async def _build_system_prompt(state: State) -> str:
    metadata = state["metadata"]
    timezone_name = metadata["timezone"]
    current_time = (
        datetime.now(timezone.utc)
        .astimezone(ZoneInfo(timezone_name))
        .isoformat()
    )
    recent_glimmers = None

    if metadata["memory_enabled"]:
        recent_glimmers = "\n".join(
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
            for glimmer in await get_recent_glimmers(metadata["user_id"], limit=5)
        )

    return system_prompt(
        metadata["lang"],
        current_time=current_time,
        recent_glimmers=recent_glimmers,
    )


def _visible_text(message: AIMessage) -> str:
    return strip_conversation_options_markup(message.content.strip())


async def _stream_ai_message(model: Any, messages: list[Any]) -> AIMessage:
    final_chunk: AIMessageChunk | None = None
    content_chunks: list[str] = []
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
        if not isinstance(chunk.content, str):
            continue

        content_chunks.append(chunk.content)
        visible_delta = consume_conversation_options_stream_delta(
            option_state,
            chunk.content,
        )
        _stream_message_delta(visible_delta)

    if final_chunk is None:
        return AIMessage(content="")

    return AIMessage(
        content="".join(content_chunks),
        additional_kwargs=final_chunk.additional_kwargs,
        response_metadata=final_chunk.response_metadata,
        tool_calls=final_chunk.tool_calls,
        invalid_tool_calls=final_chunk.invalid_tool_calls,
        id=final_chunk.id,
        usage_metadata=final_chunk.usage_metadata,
    )


def _stream_resonance_matches(resonance_matches: list[Any]) -> None:
    if not resonance_matches:
        return

    content = ResonanceMatchContent(matches=resonance_matches)
    get_stream_writer()(ResonanceMatchEvent(content=content))


def _stream_conversation_options(content: str) -> None:
    try:
        _, options = parse_conversation_options_response(content, expected_count=3)
    except ValueError:
        return

    option_content = OptionContent(options=options)
    get_stream_writer()(OptionEvent(content=option_content))


def _stream_message_delta(delta: str) -> None:
    if not delta:
        return

    content = DeltaContent(delta=delta, display_type="starsea")
    get_stream_writer()(DeltaEvent(content=content))


def _local_datetime_string(value: str, timezone_name: str) -> str:
    normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
    parsed = datetime.fromisoformat(normalized)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(ZoneInfo(timezone_name)).isoformat()
