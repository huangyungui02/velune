from __future__ import annotations

import asyncio
import logging
from collections.abc import Awaitable, Callable
from typing import Any

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

from app.shared import normalize_lang
from app.shared import Lang
from app.echo.worker import compose_worker
from app.sse import sse_event, sse_response
from starlette.requests import ClientDisconnect
from app.repositories import (
    get_user_id_from_auth_header,
)

router = APIRouter()
logger = logging.getLogger(__name__)
ECHO_MODEL = "qwen3.5-flash"

@router.post("/{lang}/glimmers/compose")
async def compose_glimmer(lang: Lang, request: Request):
    try:
        lang = normalize_lang(lang)
    except ValueError as error:
        return JSONResponse({"error": str(error)}, status_code=400)

    try:
        body = await request.json()
    except Exception:  # noqa: BLE001
        return JSONResponse({"error": "Invalid JSON body"}, status_code=400)

    glimmer_id = str(body.get("glimmerId", "")).strip()
    content = str(body.get("content", "")).strip()

    if not glimmer_id:
        return JSONResponse({"error": "Missing glimmerId"}, status_code=400)
    if not content:
        return JSONResponse({"error": "Missing content"}, status_code=400)

    async def event_stream():
        queue: asyncio.Queue[dict[str, Any] | None] = asyncio.Queue()
        stream_closed = asyncio.Event()

        async def send(payload: dict[str, Any]) -> None:
            if stream_closed.is_set():
                return
            await queue.put(payload)

        async def worker() -> None:
            try:
                user_id = get_user_id_from_auth_header(request.headers.get("Authorization"))
                await compose_worker(
                    user_id=user_id,
                    lang=lang,
                    glimmer_id=glimmer_id,
                    content=content,
                    send=send,
                )
            finally:
                if not stream_closed.is_set():
                    await queue.put(None)

        worker_task = asyncio.create_task(worker())
        try:
            while True:
                payload = await queue.get()
                if payload is None:
                    break
                yield sse_event(payload)
        except (ClientDisconnect, asyncio.CancelledError):
            stream_closed.set()
            return

        await worker_task

    return sse_response(event_stream())
