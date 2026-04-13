from __future__ import annotations

from app.repositories import ChapterContext
from app.chat.chapters.reply import build_chapter_system_prompt
from app.shared import Lang

def build_chapter_opening_messages(
    souler_name: str,
    chapter: ChapterContext,
    lang: Lang,
) -> list[dict[str, str]]:
    system_prompt = build_chapter_system_prompt(souler_name, chapter, lang)
    user_prompt = "开始" if lang == "zh" else "Start"
    return [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ]
