from __future__ import annotations

import html
import re
from dataclasses import dataclass

OPTIONS_OPEN = "<options>"
OPTIONS_CLOSE = "</options>"
OPTION_RE = re.compile(r"<opt>(.*?)</opt>", re.DOTALL | re.IGNORECASE)
OPTIONS_BLOCK_RE = re.compile(
    r"\n*<options>.*?</options>\s*",
    re.DOTALL | re.IGNORECASE,
)


@dataclass
class ConversationOptionStreamState:
    raw_chunks: list[str]
    output_chunks: list[str]
    pending: str
    phase: str


def parse_conversation_options_response(
    raw_content: str,
    *,
    expected_count: int = 4,
) -> tuple[str, list[str]]:
    content = raw_content.strip()
    if not content:
        raise ValueError("Empty conversation response")

    content_lower = content.lower()
    open_index = content_lower.rfind(OPTIONS_OPEN)
    if open_index < 0:
        raise ValueError("Missing conversation options block")

    close_index = content_lower.find(OPTIONS_CLOSE, open_index + len(OPTIONS_OPEN))
    if close_index < 0:
        raise ValueError("Missing conversation options end marker")

    content_body = content[:open_index].strip()
    if not content_body:
        raise ValueError("Missing conversation content body")

    block = content[open_index : close_index + len(OPTIONS_CLOSE)]
    options = normalize_options(
        html.unescape(match.group(1)).strip() for match in OPTION_RE.finditer(block)
    )
    if len(options) != expected_count:
        raise ValueError(
            f"Conversation options must contain exactly {expected_count} items"
        )

    return content_body, options


def consume_conversation_options_stream_delta(
    state: ConversationOptionStreamState,
    delta: str,
) -> str:
    state.raw_chunks.append(delta)
    state.pending += delta
    visible_parts: list[str] = []

    while state.pending:
        pending_lower = state.pending.lower()

        if state.phase == "done":
            break

        if state.phase == "streaming_content":
            marker_lower = OPTIONS_OPEN.lower()
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

        raise ValueError(f"Unknown conversation option stream phase: {state.phase}")

    return "".join(visible_parts)


def flush_conversation_options_stream(state: ConversationOptionStreamState) -> str:
    if state.phase != "streaming_content" or not state.pending:
        return ""

    visible = state.pending
    state.pending = ""
    state.output_chunks.append(visible)
    return visible


def strip_conversation_options_markup(content: str) -> str:
    return OPTIONS_BLOCK_RE.sub("", content).strip()


def normalize_options(raw_options: object) -> list[str]:
    seen: set[str] = set()
    options: list[str] = []

    for option in raw_options or []:
        normalized = " ".join(str(option).strip().split())
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        options.append(normalized)
        if len(options) == 4:
            break

    return options
