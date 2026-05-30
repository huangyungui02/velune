from __future__ import annotations

import logging

from fastapi import HTTPException, Request
from pydantic import ValidationError

from app.core.errors import UnauthorizedError, error_log_payload, error_message
from app.repositories import get_user_id_from_auth_header
from app.schemas.common import Lang, validate_lang

logger = logging.getLogger(__name__)


async def require_lang(lang: str) -> Lang:
    try:
        return validate_lang(lang)
    except ValidationError as error:
        raise HTTPException(status_code=400, detail="Invalid lang, must be one of: en, zh") from error


async def require_user_id(request: Request) -> str:
    try:
        return await get_user_id_from_auth_header(request.headers.get("Authorization"))
    except UnauthorizedError as error:
        raise HTTPException(status_code=401, detail="Unauthorized") from error
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to validate auth: %s", error_log_payload(error))
        raise HTTPException(status_code=400, detail=error_message(error)) from error
