from __future__ import annotations

from typing import Any, Literal

Lang = Literal["chs", "en"]

RESOLVED_NAME_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "resolved_name": {
            "type": "string",
        }
    },
    "required": ["resolved_name"],
    "additionalProperties": False,
}


def build_match_schema(num: int) -> dict[str, Any]:
    return {
        "type": "object",
        "properties": {
            "data": {
                "type": "array",
                "minItems": num,
                "maxItems": num,
                "items": {
                    "type": "object",
                    "properties": {
                        "souler": {"type": "string"},
                        "content": {"type": "string"},
                    },
                    "required": ["souler", "content"],
                    "additionalProperties": False,
                },
            }
        },
        "required": ["data"],
        "additionalProperties": False,
    }

def sanitize_title(raw: str, lang: Lang) -> str:
    trimmed = raw.strip().strip('"\'`')
    if not trimmed:
        return "未命名会话" if lang == "chs" else "Untitled Session"

    if lang == "chs":
        return trimmed[:16]

    return " ".join(trimmed.split()[:8])
