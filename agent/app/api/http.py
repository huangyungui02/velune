from __future__ import annotations

from fastapi.responses import JSONResponse

from app.domain.exceptions import CreditLimitError


def credit_limit_response(error: CreditLimitError) -> JSONResponse:
    return JSONResponse(
        {"code": error.code, "error": str(error)},
        status_code=402,
    )
