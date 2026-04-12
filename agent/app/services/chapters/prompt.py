from __future__ import annotations

from typing import Any

from app.chapter_reply import build_chapter_system_prompt
from app.echo_logic import Lang

from .prompt_zh import GENERATION_SYSTEM_PROMPT_ZH
from .prompt_en import GENERATION_SYSTEM_PROMPT_EN


def build_generation_messages(souler_name: str, lang: Lang) -> list[dict[str, str]]:
    if lang == "zh":
        return [
            {"role": "system", "content": GENERATION_SYSTEM_PROMPT_ZH},
            {"role": "user", "content": souler_name},
        ]

    return [
        {"role": "system", "content": GENERATION_SYSTEM_PROMPT_EN},
        {"role": "user", "content": souler_name},
    ]


def build_chapter_opening_messages(
    souler_name: str,
    chapter: dict[str, Any],
    lang: Lang,
) -> list[dict[str, str]]:
    system_prompt = build_chapter_system_prompt(souler_name, chapter, lang)
    user_prompt = "开始" if lang == "zh" else "Start"
    return [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ]
