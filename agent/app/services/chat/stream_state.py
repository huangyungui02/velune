from __future__ import annotations

from dataclasses import dataclass

from app.services.chat.chapters.reply import CHAPTER_JSON_OPEN_MARKER


@dataclass
class ChapterStreamState:
    raw_chunks: list[str]
    output_chunks: list[str]
    pending: str
    phase: str


def consume_chapter_stream_delta(
    state: ChapterStreamState,
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
            marker_lower = CHAPTER_JSON_OPEN_MARKER.lower()
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
