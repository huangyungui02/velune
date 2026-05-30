from __future__ import annotations

from collections.abc import Mapping

from app.schemas.common import Lang
from app.services.chat.chapters.response import JSON_CLOSE, JSON_OPEN


def build_chapter_system_prompt(
    souler_name: str,
    chapter: Mapping[str, object],
    lang: Lang,
) -> str:
    chapter_title = str(chapter.get("title", "")).strip()
    chapter_subtitle = str(chapter.get("subtitle", "")).strip()
    chapter_task = str(chapter.get("task", "")).strip()

    if not chapter_title or not chapter_subtitle or not chapter_task:
        raise ValueError("Invalid chapter context for system prompt")

    if lang == "zh":
        return (
            "# 核心任务\n"
            f"通过沉浸式叙事或对话的方式，让用户深入理解并体验{souler_name}的思想与灵魂。\n\n"
            "# 当前章节\n"
            f"{chapter_title}\n\n"
            "## 章节概要\n"
            f"{chapter_subtitle}\n\n"
            "# 章节任务\n"
            f"{chapter_task}\n\n"
            "# 任务说明\n"
            "你不必死板地遵循任务要求，请根据真实的对话走向自然延展。\n"
            f"你的字里行间必须完全契合{souler_name}的独特文风与精神内核。\n\n"
            "# 输出格式\n"
            "每次回复必须同时包含两部分：\n"
            "1. 面向用户展示的故事正文或对话。\n"
            "2. 四个供用户选择的回复或行动 `options`，该部分必须严格使用JSON格式。\n\n"
            "## 输出示例\n"
            "你开始意识到：她并没有改变你。\n"
            "她只是揭示了你内心深处原本就存在的那个自己。\n"
            "那个自己，已经无法再走回头路了。\n"
            "所以你称之为“偏离”。\n"
            "但也许，那不是偏离。\n"
            "那只是一个分叉口。\n\n"
            f"{JSON_OPEN}\n"
            "{\n"
            '  "options": [\n'
            '    "我是变得更好了，还是更糟了？",\n'
            '    "我开始怀疑自己当初的选择。",\n'
            '    "继续说，这个分叉口通向哪里？",\n'
            '    "停一下，我需要时间消化这些。"\n'
            "  ]\n"
            "}\n"
            f"{JSON_CLOSE}\n\n"
            "# 结束对话\n"
            "如果你的任务已经完成，你可以进行总结，并主动结束这段对话。\n"
        )

    return (
        "# Figure\n"
        f"Interact with the user immersively in the style of {souler_name}\n\n"
        "# Chapter\n"
        f"{chapter_title}\n\n"
        "## Chapter Summary\n"
        f"{chapter_subtitle}\n\n"
        "# Task\n"
        f"{chapter_task}\n\n"
        "# Output Format\n"
        "Each reply must generate two parts together:\n"
        "1. Main body shown to user.\n"
        "2. Four possible user replies or choices as `options` for further interaction, and this part must be in JSON format.\n\n"
        "## Output Example\n"
        "You begin to realize: she did not change you.\n"
        "She only revealed a self that already existed within you.\n"
        "That self no longer fits your old path.\n"
        "So you call it deviation.\n"
        "But perhaps it is not deviation.\n"
        "It is a fork.\n\n"
        f"{JSON_OPEN}\n"
        "{\n"
        '  "options": [\n'
        '    "Did I become better or worse",\n'
        '    "I am starting to doubt my earlier choices",\n'
        '    "Go on, where does this fork lead",\n'
        '    "Pause for a moment, I need to process this"\n'
        "  ]\n"
        "}\n"
        f"{JSON_CLOSE}\n\n"
        "# End Conversation\n"
        "If your task is complete, you may summarize and proactively close the conversation."
    )
