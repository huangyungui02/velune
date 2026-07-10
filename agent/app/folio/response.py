from __future__ import annotations

import html
import re
from dataclasses import dataclass, field

OPTIONS_OPEN = "<options>"
OPTIONS_CLOSE = "</options>"
END_MARKER = "<end>"
OPTION_RE = re.compile(r"<opt>(.*?)</opt>", re.DOTALL | re.IGNORECASE)


@dataclass
class FolioStreamState:
    raw_chunks: list[str] = field(default_factory=list)
    output_chunks: list[str] = field(default_factory=list)
    pending: str = ""
    reached_marker: bool = False


def parse_folio_response(raw_content: str) -> tuple[str, list[str], bool]:
    content = raw_content.strip()
    if not content:
        raise ValueError("Empty folio response")

    end_index = content.rfind(END_MARKER)
    if end_index >= 0:
        body = content[:end_index].strip()
        if not body or content[end_index + len(END_MARKER) :].strip():
            raise ValueError("Invalid folio end marker")
        return body, [], True

    content_lower = content.lower()
    open_index = content_lower.rfind(OPTIONS_OPEN)
    if open_index < 0:
        raise ValueError("Missing folio options block")
    close_index = content_lower.find(OPTIONS_CLOSE, open_index + len(OPTIONS_OPEN))
    if close_index < 0 or content[close_index + len(OPTIONS_CLOSE) :].strip():
        raise ValueError("Invalid folio options block")

    body = content[:open_index].strip()
    options = [
        html.unescape(match.group(1)).strip()
        for match in OPTION_RE.finditer(content[open_index : close_index + len(OPTIONS_CLOSE)])
    ]
    if not body or len(options) != 3 or any(not option for option in options):
        raise ValueError("Folio options must contain exactly 3 items")
    return body, options, False


def consume_folio_stream_delta(state: FolioStreamState, delta: str) -> str:
    state.raw_chunks.append(delta)
    state.pending += delta
    if state.reached_marker:
        return ""

    pending_lower = state.pending.lower()
    marker_indices = [
        index
        for index in (pending_lower.find(OPTIONS_OPEN), state.pending.find(END_MARKER))
        if index >= 0
    ]
    if marker_indices:
        marker_index = min(marker_indices)
        visible = state.pending[:marker_index]
        state.pending = state.pending[marker_index:]
        state.reached_marker = True
        if visible:
            state.output_chunks.append(visible)
        return visible

    hold = max(len(OPTIONS_OPEN), len(END_MARKER)) - 1
    if len(state.pending) <= hold:
        return ""

    visible = state.pending[:-hold]
    state.pending = state.pending[-hold:]
    state.output_chunks.append(visible)
    return visible
