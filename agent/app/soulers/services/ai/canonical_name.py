from __future__ import annotations

from pydantic import BaseModel

from app.core.llm import DEFAULT_MODEL, complete_structured


class CanonicalName(BaseModel):
    canonical_name: str


PROMPT_ZH = (
    "将给定人物名返回为规范人物名。使用大众最熟知的名字。"
    '仅输出 JSON，例如 {"canonical_name":"弗里德里希·尼采"}。'
)
PROMPT_EN = (
    "Given a person name, return a canonical person name. "
    'Output JSON only, for example {"canonical_name":"Friedrich Nietzsche"}.'
)
PROMPT = {"zh": PROMPT_ZH, "en": PROMPT_EN}


async def canonicalize_souler_name(name: str, lang: str) -> str:
    result = await complete_structured(
        [
            {"role": "system", "content": PROMPT[lang]},
            {"role": "user", "content": name},
        ],
        model=DEFAULT_MODEL,
        schema=CanonicalName,
        temperature=0.25,
    )
    canonical_name = result.canonical_name.strip()
    if not canonical_name:
        raise ValueError("canonical souler name is empty")
    return canonical_name
