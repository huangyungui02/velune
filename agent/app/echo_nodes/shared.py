from __future__ import annotations

from typing import Any

Lang = str
SUPPORTED_LANGS: frozenset[Lang] = frozenset({"en", "zh"})
INVALID_LANG_ERROR = "Invalid lang, must be one of: en, zh"


def normalize_lang(lang: str) -> Lang:
    normalized = str(lang).strip().lower()
    if normalized not in SUPPORTED_LANGS:
        raise ValueError(INVALID_LANG_ERROR)
    return normalized


def build_match_schema(num: int) -> dict[str, Any]:
    return {
        "type": "object",
        "properties": {
            "data": {
                "type": "array",
                "minItems": num,
                "maxItems": num,
                "items": {"type": "string"},
            }
        },
        "required": ["data"],
        "additionalProperties": False,
    }


def sanitize_title(raw: str, lang: Lang) -> str:
    trimmed = raw.strip().strip('"\'`')
    if not trimmed:
        return "未命名会话" if lang == "zh" else "Untitled Session"

    if lang == "zh":
        return trimmed[:16]

    return " ".join(trimmed.split()[:8])
