from __future__ import annotations

import json
from typing import Any

from app.domain.exceptions import CreditLimitError, UnauthorizedError

__all__ = [
    "CreditLimitError",
    "UnauthorizedError",
    "safe_json_stringify",
    "error_message",
    "error_log_payload",
    "credit_error_payload",
]


def safe_json_stringify(value: Any) -> str | None:
    try:
        return json.dumps(value, ensure_ascii=False)
    except Exception:
        return None


def error_message(error: Any) -> str:
    if isinstance(error, Exception):
        message = str(error).strip()
        if message:
            return message

    if isinstance(error, str) and error.strip():
        return error

    if isinstance(error, dict):
        for key in ("message", "error", "details", "hint"):
            value = error.get(key)
            if isinstance(value, str) and value.strip():
                return value

        serialized = safe_json_stringify(error)
        if serialized and serialized != "{}":
            return serialized

    return "Unknown error"


def error_log_payload(error: Any) -> Any:
    if isinstance(error, Exception):
        return {
            "name": error.__class__.__name__,
            "message": str(error),
        }
    return safe_json_stringify(error) or str(error)


def credit_error_payload(error: CreditLimitError) -> dict[str, Any]:
    return {
        "type": "error",
        "code": error.code,
        "message": str(error),
    }
