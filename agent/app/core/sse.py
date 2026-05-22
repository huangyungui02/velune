from __future__ import annotations

import json
from typing import Any

from fastapi.responses import StreamingResponse

SSE_HEADERS = {
    "Cache-Control": "no-cache, no-transform",
    "Connection": "keep-alive",
    "X-Accel-Buffering": "no",
}


def sse_event(payload: dict[str, Any]) -> str:
    return f"data: {json.dumps(payload, ensure_ascii=False)}\n\n"


async def emit_once(payload: dict[str, Any]):
    yield sse_event(payload)


def sse_response(events) -> StreamingResponse:
    return StreamingResponse(
        events,
        media_type="text/event-stream; charset=utf-8",
        headers=SSE_HEADERS,
    )
