from __future__ import annotations

from typing import Any

from app.config import get_settings
from app.llm import complete_json
from app.routes.flow.prompts import build_resonance_messages
from app.routes.flow.schemas import FLOW_MODEL, RESONANCE_SCHEMA
from app.shared import Lang

settings = get_settings()


async def match_resonance_figures(
    *,
    content: str,
    keywords: list[str],
    lang: Lang,
) -> list[dict[str, str]]:
    payload = await complete_json(
        build_resonance_messages(content=content, keywords=keywords, lang=lang),
        model=FLOW_MODEL,
        schema_name="resonance_figures",
        schema=RESONANCE_SCHEMA,
        temperature=settings.MODEL_S_TEMPERATURE,
    )
    figures = normalize_figures(payload)
    if len(figures) < 5:
        raise ValueError("Model returned fewer than 5 figures")
    return figures[:5]


def normalize_figures(payload: Any) -> list[dict[str, str]]:
    if not isinstance(payload, dict):
        raise ValueError("Model returned non-object JSON")

    raw_figures = payload.get("figures")
    if not isinstance(raw_figures, list):
        raise ValueError("Model returned invalid figures")

    figures: list[dict[str, str]] = []
    seen: set[str] = set()
    for item in raw_figures:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name", "")).strip()
        reason = str(item.get("reason", "")).strip()
        if not name or not reason or name in seen:
            continue
        seen.add(name)
        figures.append({"name": name, "reason": reason})

    return figures
