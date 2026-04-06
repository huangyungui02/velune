from __future__ import annotations

from app.config import get_settings
from app.llm import complete_text

from .shared import Lang

settings = get_settings()

ANSWER_PROMPT_TEMPLATE: dict[Lang, str] = {
    "chs": "请以{souler_name}的风格，根据用户写下的想法，写下一段具有深度的文字，请不要直接回复用户。",
    "en": "Please write a profound passage in the style of {souler_name} based on the user's thoughts. Do not reply to the user directly.",
}


async def souler_answer(content: str, souler_name: str, lang: Lang) -> str:
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
        temperature=settings.MODEL_S_TEMPERATURE,
    )
