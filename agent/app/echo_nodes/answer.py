from __future__ import annotations

from app.config import get_settings
from app.llm import complete_text

from .shared import Lang

settings = get_settings()

ANSWER_PROMPT_TEMPLATE: dict[Lang, str] = {
    "zh": "请以{souler_name}的思想和风格，根据用户写下的想法，写下一段具有深度共鸣的回响。",
    "en": "Please write a profound passage in the thought and style of {souler_name} based on the user's thoughts.",
}


async def souler_answer(
    content: str,
    souler_name: str,
    lang: Lang,
    *,
    model: str,
) -> str:
    return await complete_text(
        [
            {
                "role": "system",
                "content": ANSWER_PROMPT_TEMPLATE[lang].format(
                    souler_name=souler_name.strip()
                ),
            },
            {"role": "user", "content": content},
        ],
        model=model,
        temperature=settings.MODEL_S_TEMPERATURE,
    )
