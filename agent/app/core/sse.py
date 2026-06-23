from __future__ import annotations

import json
from typing import Any

from fastapi.responses import StreamingResponse

SSE_HEADERS = {
    "Cache-Control": "no-cache, no-transform",
    "Connection": "keep-alive",
    "X-Accel-Buffering": "no",
}


def sse_event(event_data: dict[str, Any]) -> str:
    return f"data: {json.dumps(event_data, ensure_ascii=False)}\n\n"


async def emit_once(event_data: dict[str, Any]):
    yield sse_event(event_data)


def sse_response(events) -> StreamingResponse:
    return StreamingResponse(
        events,
        media_type="text/event-stream; charset=utf-8",
        headers=SSE_HEADERS,
    )
