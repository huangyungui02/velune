from __future__ import annotations

from collections.abc import Callable

from app.config import get_settings
from app.llm import complete_text

from .shared import Lang

settings = get_settings()

ANSWER_PROMPT: dict[Lang, Callable[[str], str]] = {
    "en": lambda prompt: (
        "# Role\n"
        f"{prompt}\n\n"
        "# Task\n"
        "Respond to the user's soul fragment in this persona.\n\n"
        "# Output\n"
        "Return only the response content.\n"
        "The response must be in English only."
    ),
    "chs": lambda prompt: (
        "# 角色\n"
        f"{prompt}\n\n"
        "# 任务\n"
        "以此角色身份回应用户的灵魂碎片。\n\n"
        "# 输出\n"
        "仅返回回复内容。\n"
        "回复内容必须只使用中文。"
    ),
}


async def souler_answer(content: str, prompt: str, lang: Lang) -> str:
    return await complete_text(
        [
            {"role": "system", "content": ANSWER_PROMPT[lang](prompt)},
            {"role": "user", "content": content},
        ],
        temperature=settings.MODEL_S_TEMPERATURE,
    )
