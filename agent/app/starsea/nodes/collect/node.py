from __future__ import annotations

import json
from typing import TYPE_CHECKING, Any

from langchain_core.messages import AIMessage, AIMessageChunk, HumanMessage, SystemMessage
from langgraph.config import get_stream_writer

from app.core.llm import DEFAULT_MODEL, create_chat_model
from app.starsea.messages import format_messages

from .prompt import system_prompt

if TYPE_CHECKING:
    from app.starsea.state import State

COLLECT_MODEL = DEFAULT_MODEL
COLLECT_TEMPERATURE = 0.45
META_START = "<glimmer_meta>"
META_END = "</glimmer_meta>"


def collect_node(state: State) -> dict[str, Any]:
    lang = _state_lang(state)
    model = create_chat_model(model=_state_model(state), temperature=COLLECT_TEMPERATURE)
    response = _stream_ai_message(
        model,
        [
            SystemMessage(content=system_prompt(lang)),
            HumanMessage(content=format_messages(state["messages"], lang)),
        ],
    )
    content, keywords, blessing = _parse_collect_output(_content_text(response.content))
    message = AIMessage(content=content)

    return {
        "messages": [message],
        "glimmer": {
            "content": content,
            "keywords": keywords,
            "blessing": blessing,
        },
    }


def _state_lang(state: State) -> str:
    return "zh" if state.get("metadata", {}).get("lang") == "zh" else "en"


def _state_model(state: State) -> str:
    model = str(state.get("metadata", {}).get("model") or "").strip()
    return model or COLLECT_MODEL


def _stream_ai_message(model: Any, messages: list[Any]) -> AIMessage:
    final_chunk: AIMessageChunk | None = None
    filter_state = _CollectStreamFilter()
    for chunk in model.stream(messages):
        if not isinstance(chunk, AIMessageChunk):
            continue

        final_chunk = chunk if final_chunk is None else final_chunk + chunk
        visible_delta = filter_state.push(_content_text(chunk.content))
        _stream_message_delta(visible_delta)

    _stream_message_delta(filter_state.finish())

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


def _parse_collect_output(raw_content: str) -> tuple[str, list[str], str]:
    start_index = raw_content.find(META_START)
    if start_index < 0:
        return raw_content.strip(), [], ""

    visible_content = raw_content[:start_index].strip()
    meta_start_index = start_index + len(META_START)
    end_index = raw_content.find(META_END, meta_start_index)
    if end_index < 0:
        return visible_content, [], ""

    meta_text = raw_content[meta_start_index:end_index].strip()
    try:
        meta = json.loads(meta_text)
    except json.JSONDecodeError:
        return visible_content, [], ""

    keywords = _clean_keywords(meta.get("keywords"))
    blessing = _clean_blessing(meta.get("blessing"))
    return visible_content, keywords, blessing


def _clean_keywords(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []

    keywords: list[str] = []
    seen: set[str] = set()
    for item in value:
        keyword = str(item).strip() if item is not None else ""
        if not keyword or keyword in seen:
            continue
        seen.add(keyword)
        keywords.append(keyword)
        if len(keywords) == 3:
            break

    return keywords


def _clean_blessing(value: Any) -> str:
    return str(value).strip() if value is not None else ""


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

        keep = len(META_START) - 1
        if len(self._buffer) <= keep:
            return ""

        visible = self._buffer[:-keep]
        self._buffer = self._buffer[-keep:]
        return visible

    def finish(self) -> str:
        if self._hidden:
            return ""

        visible = self._buffer
        self._buffer = ""
        return visible
