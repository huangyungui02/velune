from __future__ import annotations

from app.repositories import ChapterContext
from app.chat.chapters.reply import build_chapter_system_prompt
from app.chat.preferences import ReplyLength, apply_reply_length_prompt
from app.shared import Lang


CHAPTER_OPENING_PROMPT: dict[Lang, str] = {
    "zh": (
        "【章节开场生成请求】\n"
        "这不是用户在对话中的发言，而是系统在用户点击章节开始按钮后发出的启动信号。\n"
        "请不要回应、解释、质疑或反驳“开始”这个动作。\n"
        "请直接进入当前章节：用第一人称可体验的方式，输出一段场景铺陈或开场对话，"
        "让用户自然站到这一章的处境里。\n"
        "结尾必须按系统要求提供四个 options。"
    ),
    "en": (
        "[Chapter opening generation request]\n"
        "This is not a user utterance inside the conversation. It is a system trigger "
        "sent after the user taps the chapter start button.\n"
        "Do not answer, explain, question, or push back against the word Start.\n"
        "Enter the current chapter directly: write an immersive scene-setting opening "
        "or first line of dialogue that naturally places the user inside this chapter.\n"
        "End with exactly four options as required by the system instructions."
    ),
}


def build_chapter_opening_messages(
    souler_name: str,
    chapter: ChapterContext,
    lang: Lang,
    reply_length: ReplyLength = "standard",
) -> list[dict[str, str]]:
    system_prompt = apply_reply_length_prompt(
        build_chapter_system_prompt(souler_name, chapter, lang),
        lang,
        reply_length,
    )
    return [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": CHAPTER_OPENING_PROMPT[lang]},
    ]
