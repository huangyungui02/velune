from __future__ import annotations

from app.config import get_settings
from app.core.lang import Lang
from app.core.text import sanitize_title
from app.domain.types import Chapter, Message, Session
from app.infra.llm import DEFAULT_MODEL, complete_text
from app.services.chat.chapters.format import build_chapter_system_prompt
from app.services.chat.preferences import ReplyLength, apply_reply_length_prompt

settings = get_settings()


def build_system_prompt(
    name: str,
    lang: Lang,
    chapter: Chapter | None = None,
    reply_length: ReplyLength = "standard",
) -> str:
    if chapter:
        return apply_reply_length_prompt(
            build_chapter_system_prompt(name, chapter, lang),
            lang,
            reply_length,
        )

    template: dict[Lang, str] = {
        "zh": "请以{name}的思想和风格与用户进行深度对话",
        "en": "Please have a deep conversation with the user in the thought and style of {name}.",
    }
    return apply_reply_length_prompt(template[lang].format(name=name), lang, reply_length)


def build_prompt_messages(
    session: Session,
    history: list[Message],
    content: str,
    lang: Lang,
    reply_length: ReplyLength = "standard",
) -> list[dict[str, str]]:
    prompt_messages: list[dict[str, str]] = [
        {
            "role": "system",
            "content": build_system_prompt(
                session["souler"]["name"],
                lang,
                session.get("chapter"),
                reply_length,
            ),
        }
    ]

    for item in history:
        prompt_messages.append(
            {
                "role": "assistant" if item["role"] == "assistant" else "user",
                "content": str(item["content"]),
            }
        )

    prompt_messages.append({"role": "user", "content": content})
    return prompt_messages


async def generate_session_title(
    user_content: str,
    reply_content: str,
    lang: Lang,
    *,
    model: str = DEFAULT_MODEL,
) -> str:
    system_prompt = (
        "根据用户消息和助手回复生成简洁聊天标题。限制 12 个字以内，不要标点，不要引号，只返回标题文本。"
        if lang == "zh"
        else "Create a concise chat title based on the user message and assistant reply. "
        "Keep it under 8 words, no punctuation, no quotes, and return only title text."
    )
    raw = await complete_text(
        [
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": f"User:\n{user_content}\n\nAssistant:\n{reply_content}",
            },
        ],
        model=model,
        temperature=settings.MODEL_S_TEMPERATURE,
    )
    return sanitize_title(raw, lang)
