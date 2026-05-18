from __future__ import annotations

import asyncio
import logging
from typing import Any

from fastapi import Request
from fastapi.responses import JSONResponse

from app.errors import UnauthorizedError, error_log_payload
from app.repositories import get_user_id_from_auth_header


async def validate_flow_auth(
    request: Request,
    logger: logging.Logger,
    *,
    label: str,
) -> JSONResponse | None:
    try:
        await asyncio.to_thread(
            get_user_id_from_auth_header,
            request.headers.get("Authorization"),
        )
    except UnauthorizedError:
        return JSONResponse({"error": "Unauthorized"}, status_code=401)
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to validate %s auth: %s", label, error_log_payload(error))
        return JSONResponse({"error": "Unauthorized"}, status_code=401)

    return None


async def read_json_body(request: Request) -> dict[str, Any] | JSONResponse:
    try:
        body = await request.json()
    except Exception:  # noqa: BLE001
        return JSONResponse({"error": "Invalid JSON body"}, status_code=400)

    if not isinstance(body, dict):
        return JSONResponse({"error": "Invalid JSON body"}, status_code=400)

    return body


def extract_content(body: dict[str, Any]) -> str:
    return str(body.get("content", "")).strip()
