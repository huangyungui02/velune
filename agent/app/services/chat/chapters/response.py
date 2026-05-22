from __future__ import annotations

import json
import re
from dataclasses import dataclass

JSON_OPEN = "---JSON---"
JSON_CLOSE = "---END_JSON---"
_TRAILING_COMMA_RE = re.compile(r",(\s*[\]}])")


@dataclass
class ChapterStreamState:
    raw_chunks: list[str]
    output_chunks: list[str]
    pending: str
    phase: str


def parse_chapter_response(raw_content: str) -> tuple[str, list[str]]:
    content = raw_content.strip()
    if not content:
        raise ValueError("Empty chapter response")

    open_index = content.find(JSON_OPEN)
    if open_index < 0:
        raise ValueError("Missing chapter JSON block")

    close_index = content.find(JSON_CLOSE, open_index + len(JSON_OPEN))
    if close_index < 0:
        raise ValueError("Missing chapter JSON end marker")

    content_body = content[:open_index].strip()
    if not content_body:
        raise ValueError("Missing chapter content body")

    json_block = content[open_index + len(JSON_OPEN) : close_index].strip()
    if not json_block:
        raise ValueError("Empty chapter JSON block")

    try:
        options_payload: object = json.loads(json_block)
    except json.JSONDecodeError:
        normalized_json_block = _TRAILING_COMMA_RE.sub(r"\1", json_block)
        options_payload = json.loads(normalized_json_block)

    if not isinstance(options_payload, dict):
        raise ValueError("Invalid chapter JSON payload")

    options_raw = options_payload.get("options")
    if not isinstance(options_raw, list):
        raise ValueError("Chapter options must be a list")

    options = [
        " ".join(str(item).strip().split()) for item in options_raw if str(item).strip()
    ]
    if len(options) != 4:
        raise ValueError("Chapter options must contain exactly 4 items")

    return content_body, options


def consume_chapter_stream_delta(state: ChapterStreamState, delta: str) -> str:
    state.raw_chunks.append(delta)
    state.pending += delta
    visible_parts: list[str] = []

    while state.pending:
        pending_lower = state.pending.lower()

        if state.phase == "done":
            break

        if state.phase == "streaming_content":
            marker_lower = JSON_OPEN.lower()
            options_open_index = pending_lower.find(marker_lower)
            if options_open_index >= 0:
                visible = state.pending[:options_open_index]
                if visible:
                    state.output_chunks.append(visible)
                    visible_parts.append(visible)
                state.pending = state.pending[options_open_index:]
                state.phase = "done"
                break

            hold = len(marker_lower) - 1
            if len(state.pending) <= hold:
                break

            visible = state.pending[:-hold]
            state.pending = state.pending[-hold:]
            if visible:
                state.output_chunks.append(visible)
                visible_parts.append(visible)
            break

        raise ValueError(f"Unknown chapter stream phase: {state.phase}")

    return "".join(visible_parts)
