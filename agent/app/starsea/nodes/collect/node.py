from __future__ import annotations

import json
from typing import TYPE_CHECKING, Any

from langchain_core.messages import AIMessage, AIMessageChunk, HumanMessage, SystemMessage

from app.core.llm import DEFAULT_MODEL, create_chat_model
from app.starsea.schemas.events import DeltaEvent
from app.starsea.schemas.model import DeltaContent
from app.starsea.stream_events import emit_starsea_event
from app.starsea.messages import format_messages

from .prompt import system_prompt

if TYPE_CHECKING:
    from app.starsea.state import State

COLLECT_MODEL = DEFAULT_MODEL
COLLECT_TEMPERATURE = 0.45
META_START = "<glimmer_meta>"
META_END = "</glimmer_meta>"


def collect_node(state: State) -> dict[str, Any]:
    lang = state["metadata"]["lang"]
    model = create_chat_model(model=COLLECT_MODEL, temperature=COLLECT_TEMPERATURE)
    response = _stream_ai_message(
        model,
        [
            SystemMessage(content=system_prompt(lang)),
            HumanMessage(content=format_messages(state["messages"], lang)),
        ],
    )
    glimmer = _parse_collect_output(response.content)
    message = AIMessage(content=glimmer["content"])

    return {
        "messages": [message],
        "glimmer": glimmer,
    }


def _parse_collect_output(raw_content: str) -> dict[str, Any]:
    content, separator, remainder = raw_content.partition(META_START)
    if not separator:
        return {
            "content": raw_content.strip(),
            "keywords": [],
            "blessing": "",
        }

    meta_text, separator, _ = remainder.partition(META_END)
    if not separator:
        return {
            "content": content.strip(),
            "keywords": [],
            "blessing": "",
        }

    try:
        meta = json.loads(meta_text.strip())
    except json.JSONDecodeError:
        meta = {}
    if not isinstance(meta, dict):
        meta = {}

    return {
        "content": content.strip(),
        "keywords": meta.get("keywords", []),
        "blessing": str(meta.get("blessing") or "").strip(),
    }


def _stream_ai_message(model: Any, messages: list[Any]) -> AIMessage:
    final_chunk: AIMessageChunk | None = None
    content_chunks: list[str] = []
    filter_state = _CollectStreamFilter()
    for chunk in model.stream(messages):
        if not isinstance(chunk, AIMessageChunk):
            continue

        final_chunk = chunk if final_chunk is None else final_chunk + chunk
        if not isinstance(chunk.content, str):
            continue

        content_chunks.append(chunk.content)
        visible_delta = filter_state.push(chunk.content)
        _stream_message_delta(visible_delta)

    _stream_message_delta(filter_state.finish())

    if final_chunk is None:
        return AIMessage(content="")

    return AIMessage(
        content="".join(content_chunks),
        additional_kwargs=final_chunk.additional_kwargs,
        response_metadata=final_chunk.response_metadata,
        id=final_chunk.id,
        usage_metadata=final_chunk.usage_metadata,
    )


def _stream_message_delta(delta: str) -> None:
    if not delta:
        return

    content = DeltaContent(delta=delta, display_type="collect")
    emit_starsea_event(DeltaEvent(content=content))


class _CollectStreamFilter:
    def __init__(self) -> None:
        self._buffer = ""
        self._hidden = False

    def push(self, delta: str) -> str:
        if not delta or self._hidden:
            return ""

        self._buffer += delta
        start_index = self._buffer.find(META_START)
        if start_index >= 0:
            visible = self._buffer[:start_index].rstrip()
            self._buffer = ""
            self._hidden = True
            return visible

        keep_length = len(META_START) - 1
        if len(self._buffer) <= keep_length:
            return ""

        visible = self._buffer[:-keep_length]
        self._buffer = self._buffer[-keep_length:]
        return visible

    def finish(self) -> str:
        if self._hidden:
            return ""

        visible = self._buffer
        self._buffer = ""
        return visible
