from __future__ import annotations

import asyncio
import logging

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from starlette.requests import ClientDisconnect

from app.errors import error_log_payload
from app.routes.flow.common import extract_content, read_json_body, validate_flow_auth
from app.routes.flow.resonances import match_resonance_figures
from app.routes.flow.themes import identify_life_themes
from app.shared import Lang, normalize_lang
from app.sse import sse_event, sse_response

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/{lang}/flow")
async def flow(lang: Lang, request: Request):
    try:
        lang = normalize_lang(lang)
    except ValueError as error:
        return JSONResponse({"error": str(error)}, status_code=400)

    auth_error = await validate_flow_auth(request, logger, label="flow")
    if auth_error is not None:
        return auth_error

    body = await read_json_body(request)
    if isinstance(body, JSONResponse):
        return body

    content = extract_content(body)
    if not content:
        return JSONResponse({"error": "Missing content"}, status_code=400)

    async def event_stream():
        try:
            keywords = await identify_life_themes(content=content, lang=lang)
            yield sse_event({"type": "themes", "keywords": keywords})

            figures = await match_resonance_figures(
                content=content,
                keywords=keywords,
                lang=lang,
            )
            yield sse_event({"type": "resonances", "figures": figures})
            yield sse_event({"type": "done"})
        except (ClientDisconnect, asyncio.CancelledError):
            return
        except Exception as error:  # noqa: BLE001
            logger.error("Flow failed: %s", error_log_payload(error))
            yield sse_event(
                {
                    "type": "error",
                    "message": "The flow could not be completed.",
                }
            )

    return sse_response(event_stream())
