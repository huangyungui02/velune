from __future__ import annotations

from app.config import get_settings
from app.llm import complete_text

from .shared import Lang

settings = get_settings()

ROLE_PROMPT: dict[Lang, str] = {
    "en": "You generate role prompts. For the given person, write a concise character prompt for an LLM to simulate that person. The prompt must start with 'You are'.",
    "chs": "你是角色提示词生成器。为给定人物编写一段简洁的角色提示词，供大语言模型模拟该人物使用。提示词必须以\"你是\"开头。",
}


async def souler_prompt(souler: str, lang: Lang) -> str:
    return await complete_text(
        [
            {"role": "system", "content": ROLE_PROMPT[lang]},
            {"role": "user", "content": souler},
        ],
        temperature=settings.MODEL_S_TEMPERATURE,
    )
