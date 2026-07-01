from __future__ import annotations

from typing import TYPE_CHECKING, Any

from langchain_core.messages import AIMessage, AIMessageChunk, HumanMessage, SystemMessage
from langgraph.config import get_stream_writer

from app.core.conversation_options import (
    ConversationOptionStreamState,
    consume_conversation_options_stream_delta,
    parse_conversation_options_response,
    strip_conversation_options_markup,
)
from app.core.llm import DIVINATION_MODEL, create_deepseek_chat_model
from app.starsea.schemas.events import DeltaEvent, OptionEvent
from app.starsea.schemas.model import DeltaContent, OptionContent

from .interpretation import build_divination_user_prompt
from .prompt import SYSTEM_PROMPT

if TYPE_CHECKING:
    from app.starsea.state import State

DIVINATION_TEMPERATURE = 0.45


async def divination_node(state: State) -> dict[str, Any]:
    user_message = HumanMessage(content=_user_prompt(state))
    model = create_deepseek_chat_model(
        model=DIVINATION_MODEL,
        temperature=DIVINATION_TEMPERATURE,
        reasoning_effort="high",
        extra_body={"thinking": {"type": "enabled"}},
    )
    response = await _stream_ai_message(
        model,
        [
            SystemMessage(content=SYSTEM_PROMPT.strip()),
            *state["messages"],
            user_message,
        ],
    )
    _stream_conversation_options(response.content)

    return {
        "messages": [user_message, response],
        "archive_events": _archive_events(response.content),
    }


def _archive_events(content: Any) -> list[dict[str, Any]]:
    visible_reply = strip_conversation_options_markup(_content_text(content).strip())
    if not visible_reply:
        return []

    return [
        {
            "type": "message",
            "role": "assistant",
            "content": visible_reply,
        }
    ]

def _user_prompt(state: State) -> str:
    user_input = state["user_input"]
    if user_input["type"] != "divination":
        raise ValueError("divination content is required")

    return build_divination_user_prompt(
        divination=user_input["content"],
        timezone=state["metadata"]["timezone"],
        lang=state["metadata"]["lang"],
    )


async def _stream_ai_message(model: Any, messages: list[Any]) -> AIMessage:
    final_chunk: AIMessageChunk | None = None
    response_chunks: list[str] = []
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
        reasoning_delta = _reasoning_text(chunk)
        if reasoning_delta:
            _stream_message_delta(reasoning_delta, display_type="thinking")

        content_delta = _content_text(chunk.content)
        if content_delta:
            response_chunks.append(content_delta)

        visible_delta = consume_conversation_options_stream_delta(
            option_state,
            content_delta,
        )
        _stream_message_delta(visible_delta, display_type="starsea")

    if final_chunk is None:
        return AIMessage(content="")

    additional_kwargs = {
        key: value
        for key, value in final_chunk.additional_kwargs.items()
        if key != "reasoning_content"
    }

    return AIMessage(
        content="".join(response_chunks),
        additional_kwargs=additional_kwargs,
        response_metadata=final_chunk.response_metadata,
        tool_calls=final_chunk.tool_calls,
        invalid_tool_calls=final_chunk.invalid_tool_calls,
        id=final_chunk.id,
        usage_metadata=final_chunk.usage_metadata,
    )


def _stream_conversation_options(content: Any) -> None:
    try:
        _, options = parse_conversation_options_response(_content_text(content))
    except ValueError:
        return

    option_content = OptionContent(options=options)
    get_stream_writer()(OptionEvent(content=option_content))


def _stream_message_delta(delta: str, *, display_type: str) -> None:
    if not delta:
        return

    content = DeltaContent(delta=delta, display_type=display_type)
    get_stream_writer()(DeltaEvent(content=content))


def _reasoning_text(chunk: AIMessageChunk) -> str:
    parts: list[str] = []
    for block in getattr(chunk, "content_blocks", []) or []:
        if not isinstance(block, dict) or block.get("type") != "reasoning":
            continue
        reasoning = block.get("reasoning")
        if isinstance(reasoning, str):
            parts.append(reasoning)

    if parts:
        return "".join(parts)

    additional_reasoning = chunk.additional_kwargs.get("reasoning_content")
    if isinstance(additional_reasoning, str):
        parts.append(additional_reasoning)

    response_metadata_reasoning = chunk.response_metadata.get("reasoning_content")
    if isinstance(response_metadata_reasoning, str):
        parts.append(response_metadata_reasoning)

    return "".join(parts)


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
