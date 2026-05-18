from __future__ import annotations

from typing import Any

from app.config import get_settings
from app.llm import complete_json
from app.routes.flow.prompts import build_theme_messages
from app.routes.flow.schemas import FLOW_MODEL, THEME_SCHEMA
from app.shared import Lang

settings = get_settings()


async def identify_life_themes(*, content: str, lang: Lang) -> list[str]:
    payload = await complete_json(
        build_theme_messages(content=content, lang=lang),
        model=FLOW_MODEL,
        schema_name="life_theme_keywords",
        schema=THEME_SCHEMA,
        temperature=settings.MODEL_S_TEMPERATURE,
    )
    keywords = normalize_keywords(payload)
    if len(keywords) < 3:
        raise ValueError("Model returned fewer than 3 keywords")
    return keywords[:6]


def normalize_keywords(payload: Any) -> list[str]:
    if not isinstance(payload, dict):
        raise ValueError("Model returned non-object JSON")

    raw_keywords = payload.get("keywords")
    if not isinstance(raw_keywords, list):
        raise ValueError("Model returned invalid keywords")

    keywords: list[str] = []
    seen: set[str] = set()
    for item in raw_keywords:
        if not isinstance(item, str):
            continue
        keyword = item.strip()
        if not keyword or keyword in seen:
            continue
        seen.add(keyword)
        keywords.append(keyword)

    return keywords
