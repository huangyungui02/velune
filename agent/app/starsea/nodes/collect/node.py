from __future__ import annotations

from typing import TYPE_CHECKING, Any

from langchain_core.messages import AIMessage, AIMessageChunk, HumanMessage, SystemMessage
from langgraph.config import get_stream_writer

from app.core.llm import create_chat_model
from app.starsea.messages import format_messages

from .prompt import system_prompt

if TYPE_CHECKING:
    from app.starsea.state import State

COLLECT_MODEL = "qwen3.5-flash"
COLLECT_TEMPERATURE = 0.45


def collect_node(state: State) -> dict[str, Any]:
    lang = _state_lang(state)
    model = create_chat_model(model=COLLECT_MODEL, temperature=COLLECT_TEMPERATURE)
    response = _stream_ai_message(
        model,
        [
            SystemMessage(content=system_prompt(lang)),
            HumanMessage(content=_conversation_prompt(format_messages(state["messages"], lang), lang)),
        ],
    )
    content = _content_text(response.content).strip()
    message = AIMessage(content=content)

    return {
        "messages": [message],
        "glimmer_content": content,
    }


def _state_lang(state: State) -> str:
    return "zh" if state.get("metadata", {}).get("lang") == "zh" else "en"


def _conversation_prompt(conversation: str, lang: str) -> str:
    if lang == "zh":
        return f"完整对话：\n\n{conversation}"
    return f"Full conversation:\n\n{conversation}"


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
        id=final_chunk.id,
        usage_metadata=final_chunk.usage_metadata,
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
            "display_type": "collect",
            "delta": delta,
        }
    )


def _content_text(content: Any) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, str):
                parts.append(item)
            elif isinstance(item, dict) and isinstance(item.get("text"), str):
                parts.append(item["text"])
        return "".join(parts)
    return ""
