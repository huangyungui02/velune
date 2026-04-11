from __future__ import annotations

from app.config import get_settings
from app.llm import complete_text

from .shared import Lang

settings = get_settings()

PROFILE_PROMPT: dict[Lang, str] = {
    "en": "Write an introduction for the given person.",
    "chs": "为给定人物写一段人物简介。",
}


async def souler_profile(souler: str, lang: Lang, *, model: str) -> str:
    return await complete_text(
        [
            {"role": "system", "content": PROFILE_PROMPT[lang]},
            {"role": "user", "content": souler},
        ],
        model=model,
        temperature=settings.MODEL_S_TEMPERATURE,
    )
