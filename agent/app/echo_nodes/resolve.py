from __future__ import annotations

from app.config import get_settings
from app.llm import complete_json

from .shared import Lang, RESOLVED_NAME_SCHEMA

settings = get_settings()

RESOLVE_PROMPT: dict[Lang, str] = {
    "en": (
        "You resolve person names into the single mainstream public name that users are most likely to recognize. "
        "Given one possibly partial, abbreviated, translated, or variant name of a well-known person, return the single most common and widely recognized English name for that person. "
        "Rules: "
        "1. Return one person only. "
        "2. Prefer the name most commonly used in public discussion, education, publishing, and user-facing products. "
        "3. Do not prefer a birth name, original name, legal name, or lesser-used formal name if another name is more familiar to most people. "
        "4. Use a full name when that is the mainstream form, but keep a pen name, style name, honorific name, regnal name, or commonly used short name when that is what people primarily know the person by. "
        "5. Never cross-map different identities even if related: a fictional character name must stay a character name and must not be converted to the actor; likewise do not convert an actor to a role, or one public person to another associated person. "
        "6. Return only JSON."
    ),
    "chs": (
        "你负责将人物名字解析为用户最熟悉的主流公共名字。"
        "给定某位知名人物的一个可能不完整、简称、异译或变体名字，返回该人物唯一最常见、最广为人知、最适合展示给用户看的中文名字。"
        "规则："
        "1. 只能返回一个人物。"
        "2. 优先返回大众最熟悉、出版物和公共讨论中最常见的名字。"
        "3. 不要因为某个名字是本名、原名、学名或较正式写法，就优先返回它；如果另一个名字更广为人知，应返回更广为人知的那个。"
        "4. 当全名是主流形式时使用全名；但如果某人的笔名、号、尊称、谥号、庙号、王号或常用简称才是大众主要认知，就返回那个更常见的名字。"
        "5. 即使有关联也不要跨身份映射：虚构角色名必须保持为角色名，不能改成饰演者；同样不能把演员改成角色，或把一个人物改成与其相关的另一个人物。"
        "6. 仅返回 JSON。"
    ),
}


async def resolve_souler_name(name: str, lang: Lang) -> str:
    cleaned_name = name.strip()
    if not cleaned_name:
        return cleaned_name

    payload = await complete_json(
        [
            {"role": "system", "content": RESOLVE_PROMPT[lang]},
            {"role": "user", "content": cleaned_name},
        ],
        schema_name="resolved_souler_name",
        schema=RESOLVED_NAME_SCHEMA,
        temperature=settings.MODEL_XS_TEMPERATURE,
    )
    resolved_name = str(payload.get("resolved_name", "")).strip()
    return resolved_name or cleaned_name
