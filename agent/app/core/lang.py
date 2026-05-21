from __future__ import annotations

Lang = str
SUPPORTED_LANGS: frozenset[Lang] = frozenset({"en", "zh"})
INVALID_LANG_ERROR = "Invalid lang, must be one of: en, zh"


def normalize_lang(lang: str) -> Lang:
    normalized = str(lang).strip().lower()
    if normalized not in SUPPORTED_LANGS:
        raise ValueError(INVALID_LANG_ERROR)
    return normalized
