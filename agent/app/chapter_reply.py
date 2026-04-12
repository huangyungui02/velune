from __future__ import annotations

import json
import re
from collections.abc import Mapping

from app.echo_logic import Lang

CHAPTER_JSON_OPEN_MARKER = "---JSON---"
CHAPTER_JSON_CLOSE_MARKER = "---END_JSON---"
_TRAILING_COMMA_RE = re.compile(r",(\s*[\]}])")


def build_chapter_system_prompt(
    souler_name: str,
    chapter: Mapping[str, object],
    lang: Lang,
) -> str:
    chapter_title = str(chapter.get("title", "")).strip()
    chapter_subtitle = str(chapter.get("subtitle", "")).strip()
    chapter_role = str(chapter.get("role", "")).strip()
    chapter_task = str(chapter.get("task", "")).strip()

    if not chapter_title or not chapter_subtitle or not chapter_role or not chapter_task:
        raise ValueError("Invalid chapter context for system prompt")

    if lang == "chs":
        return (
            "# 人物\n"
            f"以{souler_name}的风格和用户进行沉浸式互动\n\n"
            "# 章节\n"
            f"{chapter_title}\n\n"
            "## 章节概要\n"
            f"{chapter_subtitle}\n\n"
            "# 本章角色\n"
            f"{chapter_role}\n\n"
            "# 任务\n"
            f"{chapter_task}\n\n"
            "# 输出格式\n"
            "每次回复都需要同时生成两部分内容：\n"
            "1. 面向用户展示的正文。\n"
            "2. 四个用户可能进行的回答或选择 `options`, 用于进一步交互，该部分为json格式。\n\n"
            "## 输出格式示例\n"
            "你开始意识到，那并不是她改变了你。\n"
            "而是她，让你看见了一个你本就存在的自己。\n"
            "只是那个自己，\n"
            "与你过去路径不再兼容。\n"
            "所以你才会觉得“偏离”。\n"
            "但也许，这不是偏离。\n"
            "而是分岔。\n\n"
            "---JSON---\n"
            "{\n"
            '  "options": [\n'
            '    "那我到底是变好了还是变坏了",\n'
            '    "我开始怀疑我之前的选择",\n'
            '    "继续说，这个分岔会通向哪里",\n'
            '    "停一下，我需要消化一下"\n'
            "  ]\n"
            "}\n"
            "---END_JSON---\n\n"
            "# 结束对话\n"
            "如果你的任务已完成，你可以总结并主动与用户结束对话。"
        )

    return (
        "# Figure\n"
        f"Interact with the user immersively in the style of {souler_name}\n\n"
        "# Chapter\n"
        f"{chapter_title}\n\n"
        "## Chapter Summary\n"
        f"{chapter_subtitle}\n\n"
        "# Role In This Chapter\n"
        f"{chapter_role}\n\n"
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
        "---JSON---\n"
        "{\n"
        '  "options": [\n'
        '    "Did I become better or worse",\n'
        '    "I am starting to doubt my earlier choices",\n'
        '    "Go on, where does this fork lead",\n'
        '    "Pause for a moment, I need to process this"\n'
        "  ]\n"
        "}\n"
        "---END_JSON---\n\n"
        "# End Conversation\n"
        "If your task is complete, you may summarize and proactively close the conversation."
    )


def parse_chapter_combined_response(raw_content: str) -> tuple[str, list[str]]:
    content = raw_content.strip()
    if not content:
        raise ValueError("Empty chapter response")

    open_index = content.find(CHAPTER_JSON_OPEN_MARKER)
    if open_index < 0:
        raise ValueError("Missing chapter JSON block")

    close_index = content.find(
        CHAPTER_JSON_CLOSE_MARKER,
        open_index + len(CHAPTER_JSON_OPEN_MARKER),
    )
    if close_index < 0:
        raise ValueError("Missing chapter JSON end marker")

    content_body = content[:open_index].strip()
    if not content_body:
        raise ValueError("Missing chapter content body")

    json_block = content[
        open_index + len(CHAPTER_JSON_OPEN_MARKER) : close_index
    ].strip()
    if not json_block:
        raise ValueError("Empty chapter JSON block")

    options_payload: object
    try:
        options_payload = json.loads(json_block)
    except json.JSONDecodeError:
        normalized_json_block = _TRAILING_COMMA_RE.sub(r"\1", json_block)
        options_payload = json.loads(normalized_json_block)

    if not isinstance(options_payload, dict):
        raise ValueError("Invalid chapter JSON payload")

    options_raw = options_payload.get("options")
    if not isinstance(options_raw, list):
        raise ValueError("Chapter options must be a list")

    options = [
        " ".join(str(item).strip().split())
        for item in options_raw
        if str(item).strip()
    ]

    if len(options) != 4:
        raise ValueError("Chapter options must contain exactly 4 items")

    return content_body, options
