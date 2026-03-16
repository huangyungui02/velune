from __future__ import annotations

from collections.abc import Callable

from app.config import get_settings
from app.llm import complete_json

from .shared import Lang, build_match_schema

settings = get_settings()

MATCH_PROMPT: dict[Lang, Callable[[int], str]] = {
    "en": lambda num: (
        f"Analyze the user's journal entry to understand their emotional state, inner thoughts, and struggles. Find exactly {num} specific figures who can deeply resonate with the user's current state of mind and continue a meaningful conversation about their thoughts. "
        "Return JSON with shape {\"data\":[{\"souler\":\"...\",\"content\":\"...\"}]}. "
        "\"souler\" MUST be the single most standard, widely used full name of a specific, well-known person. "
        "Always use the canonical full name in English, not a surname-only form, nickname, title, pen name, courtesy name, or alternative transliteration unless that is the person's primary mainstream name. "
        "Use one canonical form consistently for the same person. "
        "NEVER use generic terms, roles, or placeholders like \"Unknown\", \"Someone\", or \"A Friend\". "
        "\"content\" must be a profound, empathetic quote or response from their perspective that speaks directly to the user's soul. "
        "All \"souler\" values must be unique. The entire output must be in English."
    ),
    "chs": lambda num: (
        f"深入分析用户的日记，理解其情感状态、内在想法与挣扎。找到恰好 {num} 位能够与用户当下心境产生深度共鸣、并能顺着用户的心境继续深入探讨的具体人物。"
        "返回 JSON 格式 {\"data\":[{\"souler\":\"...\",\"content\":\"...\"}]}。"
        "\"souler\" 必须是某位具体知名人物最标准、最常见的完整中文姓名。"
        "优先使用规范全名，不要只写姓，不要使用别号、字、号、尊称、笔名或另一种译法，除非那本身就是该人物最主流的名字。"
        "同一个人必须始终使用同一种规范名字。"
        "绝不允许使用任何泛指、代词或占位符，如“Unknown”、“未知”、“某人”或“朋友”。"
        "\"content\" 应当是一句深邃、富有同理心的回应，或是该人物的一句名言，能够精准触动用户的灵魂。"
        "所有 \"souler\" 必须唯一。整个返回结果必须仅使用中文。"
    ),
}


async def match_soulers(content: str, num: int, lang: Lang) -> list[dict[str, str]]:
    payload = await complete_json(
        [
            {"role": "system", "content": MATCH_PROMPT[lang](num)},
            {"role": "user", "content": content},
        ],
        schema_name="matched_soulers",
        schema=build_match_schema(num),
        temperature=settings.MODEL_L_TEMPERATURE,
    )
    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, list):
        raise ValueError("Invalid souler match response")

    results: list[dict[str, str]] = []
    seen: set[str] = set()
    for item in data:
        if not isinstance(item, dict):
            continue
        souler = str(item.get("souler", "")).strip()
        response_content = str(item.get("content", "")).strip()
        if not souler:
            continue
        key = souler.lower()
        if key in seen:
            continue
        seen.add(key)
        results.append(
            {
                "souler": souler,
                "content": response_content,
            }
        )

    if len(results) != num:
        raise ValueError(f"Expected {num} matched soulers, got {len(results)}")

    return results
