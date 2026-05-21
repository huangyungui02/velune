from __future__ import annotations

import asyncio
import logging

from fastapi import HTTPException, Request

from app.core.lang import Lang, normalize_lang
from app.errors import UnauthorizedError, error_log_payload, error_message
from app.repositories import get_user_id_from_auth_header

logger = logging.getLogger(__name__)


async def require_lang(lang: str) -> Lang:
    try:
        return normalize_lang(lang)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


async def require_user_id(request: Request) -> str:
    try:
        return await asyncio.to_thread(
            get_user_id_from_auth_header,
            request.headers.get("Authorization"),
        )
    except UnauthorizedError as error:
        raise HTTPException(status_code=401, detail="Unauthorized") from error
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to validate auth: %s", error_log_payload(error))
        raise HTTPException(status_code=400, detail=error_message(error)) from error
