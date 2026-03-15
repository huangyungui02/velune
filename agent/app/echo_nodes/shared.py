from __future__ import annotations

from typing import Any, Literal

Lang = Literal["chs", "en"]

ALIASES_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "aliases": {
            "type": "array",
            "items": {"type": "string"},
        }
    },
    "required": ["aliases"],
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


def normalize_aliases(name: str, aliases: list[str]) -> list[str]:
    seen: set[str] = set()
    normalized: list[str] = []

    def push(candidate: str) -> None:
        cleaned = candidate.strip()
        if not cleaned:
            return
        key = cleaned.lower()
        if key in seen:
            return
        seen.add(key)
        normalized.append(cleaned)

    push(name)
    for alias in aliases:
        push(alias)

    return normalized


def sanitize_title(raw: str, lang: Lang) -> str:
    trimmed = raw.strip().strip('"\'`')
    if not trimmed:
        return "未命名会话" if lang == "chs" else "Untitled Session"

    if lang == "chs":
        return trimmed[:16]

    return " ".join(trimmed.split()[:8])
