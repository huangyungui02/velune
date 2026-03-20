from __future__ import annotations

from collections.abc import Callable

from app.config import get_settings
from app.llm import complete_json

from .shared import Lang, build_match_schema

settings = get_settings()

MATCH_PROMPT: dict[Lang, Callable[[int], str]] = {
    "en": lambda num: (
        f"Analyze the user's journal entry to understand their emotional state, inner thoughts, and struggles. Find exactly {num} specific figures who can deeply resonate with the user's current state of mind. "
        'Return JSON with shape {"data":["name1","name2",...]}. '
        "Each name MUST be the single most standard, widely used name of a specific, well-known person. "
        'NEVER use generic terms, roles, or placeholders like "Unknown", "Someone", or "A Friend". '
        "All names must be unique. The entire output must be in English."
    ),
    "chs": lambda num: (
        f"深入分析用户的日记，理解其情感状态、内在想法与挣扎。找到恰好 {num} 位能够与用户当下心境产生深度共鸣的具体人物。"
        '返回 JSON 格式 {"data":["姓名1","姓名2",...]}。'
        "每个姓名必须是某位具体知名人物最标准、最常见的中文姓名。"
        '绝不允许使用任何泛指、代词或占位符，如"未知"、"某人"或"朋友"。'
        "所有姓名必须唯一。整个返回结果必须仅使用中文。"
    ),
}


async def match_soulers(content: str, num: int, lang: Lang) -> list[str]:
    """Return *num* unique souler names that resonate with *content*."""
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

    results: list[str] = []
    seen: set[str] = set()
    for name in data:
        souler = str(name).strip()
        if not souler:
            continue
        key = souler.lower()
        if key in seen:
            continue
        seen.add(key)
        results.append(souler)

    if len(results) != num:
        raise ValueError(f"Expected {num} matched soulers, got {len(results)}")

    return results
