from __future__ import annotations

import logging

from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from app.api.deps import require_lang, require_user_id
from app.core.lang import Lang
from app.errors import error_log_payload, error_message
from app.services.soulers import canonicalize_souler_name

logger = logging.getLogger(__name__)
router = APIRouter()


class CanonicalizeSoulerRequest(BaseModel):
    name: str = Field(min_length=1, max_length=128)


@router.post("/{lang}/soulers/canonicalize")
async def canonicalize_souler_name_route(
    payload: CanonicalizeSoulerRequest,
    normalized_lang: Lang = Depends(require_lang),
    _: str = Depends(require_user_id),
):
    try:
        canonical_name = await canonicalize_souler_name(payload.name, normalized_lang)
        return JSONResponse({"canonical_name": canonical_name}, status_code=200)
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to canonicalize souler: %s", error_log_payload(error))
        return JSONResponse({"error": error_message(error)}, status_code=400)
