from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any


@dataclass
class CreditState:
    plan: str
    monthly_limit: int
    credits_remaining: int


class CreditLimitError(Exception):
    def __init__(
        self,
        message: str,
        code: str,
        plan: str,
        monthly_limit: int,
        credits_remaining: int,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.plan = plan
        self.monthly_limit = monthly_limit
        self.credits_remaining = credits_remaining


class UnauthorizedError(Exception):
    pass


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
        "plan": error.plan,
        "creditsRemaining": error.credits_remaining,
        "monthlyLimit": error.monthly_limit,
    }
