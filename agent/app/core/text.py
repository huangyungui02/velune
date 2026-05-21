from __future__ import annotations

from .lang import Lang


def sanitize_title(raw: str, lang: Lang) -> str:
    trimmed = raw.strip().strip('"\'`')
    if not trimmed:
        return "未命名会话" if lang == "zh" else "Untitled Session"

    if lang == "zh":
        return trimmed[:16]

    return " ".join(trimmed.split()[:8])
