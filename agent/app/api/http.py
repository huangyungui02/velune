from __future__ import annotations

from typing import Any

from fastapi import Request
from fastapi.responses import JSONResponse


async def json_body(request: Request) -> dict[str, Any]:
    try:
        body = await request.json()
    except Exception:  # noqa: BLE001
        return {}
    return body if isinstance(body, dict) else {}


async def required_json_body(request: Request) -> dict[str, Any]:
    try:
        body = await request.json()
    except Exception as error:  # noqa: BLE001
        raise ValueError("Invalid request body") from error
    if not isinstance(body, dict):
        raise ValueError("Invalid request body")
    return body


def error_response(message: str, status_code: int = 400) -> JSONResponse:
    return JSONResponse({"error": message}, status_code=status_code)
