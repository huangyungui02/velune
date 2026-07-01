from __future__ import annotations

from langgraph.config import get_stream_writer

from app.starsea.schemas.events import StarseaEvent


def emit_starsea_event(event: StarseaEvent) -> None:
    try:
        writer = get_stream_writer()
    except RuntimeError:
        return

    writer(event.model_dump(mode="json", exclude_none=True))
