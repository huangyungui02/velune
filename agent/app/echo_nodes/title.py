from __future__ import annotations

from app.config import get_settings
from app.llm import complete_text

from .shared import Lang, sanitize_title

settings = get_settings()

SESSION_TITLE_PROMPT: dict[Lang, str] = {
    "en": "Create a concise chat title from the user's glimmer and souler echo. Keep it under 8 words, no punctuation, no quotes, and return only the title text. Title must be in English only.",
    "zh": "根据用户 glimmer 和 souler echo 生成一个简洁会话标题。限制 8 个字以内，不要标点，不要引号，只返回标题文本。标题必须只使用中文。",
}


async def session_title(glimmer: str, echo: str, lang: Lang, *, model: str) -> str:
    raw = await complete_text(
        [
            {"role": "system", "content": SESSION_TITLE_PROMPT[lang]},
            {"role": "user", "content": f"Glimmer:\n{glimmer}\n\nEcho:\n{echo}"},
        ],
        model=model,
        temperature=settings.MODEL_S_TEMPERATURE,
    )
    return sanitize_title(raw, lang)
