from __future__ import annotations

from uuid import UUID

Lang = str
SUPPORTED_LANGS: frozenset[Lang] = frozenset({"en", "zh"})
INVALID_LANG_ERROR = "Invalid lang, must be one of: en, zh"


def normalize_lang(lang: str) -> Lang:
    normalized = str(lang).strip().lower()
    if normalized not in SUPPORTED_LANGS:
        raise ValueError(INVALID_LANG_ERROR)
    return normalized


def normalize_uuid(value: object) -> str:
    trimmed = str(value or "").strip()
    if not trimmed:
        return ""
    return str(UUID(trimmed))


def sanitize_title(raw: str, lang: Lang) -> str:
    trimmed = raw.strip().strip('"\'`')
    if not trimmed:
        return "未命名会话" if lang == "zh" else "Untitled Session"

    if lang == "zh":
        return trimmed[:16]

    return " ".join(trimmed.split()[:8])
