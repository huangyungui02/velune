from __future__ import annotations

from app.config import get_settings
from app.llm import complete_json

from .shared import ALIASES_SCHEMA, Lang, normalize_aliases

settings = get_settings()

ALIAS_PROMPT: dict[Lang, str] = {
    "en": (
        "You are an expert in entity resolution and name normalization. "
        "Generate a comprehensive list of practical aliases for a given person's name to improve search and matching accuracy.\n"
        "Rules:\n"
        "1. Canonical Full Name: Include the complete official name (e.g., \"Einstein\" -> \"Albert Einstein\").\n"
        "2. Pseudonyms & Stage Names: Include known pen names, stage names, or widely recognized monikers (e.g., \"Mark Twain\" -> \"Samuel Langhorne Clemens\").\n"
        "3. Titles & Honorifics: Include forms with commonly associated titles if they are widely used for identification (e.g., \"Gandhi\" -> \"Mahatma Gandhi\").\n"
        "4. Variant Spellings & Transliterations: Include common alternative spellings or anglicized forms (e.g., \"Dostoevsky\" -> \"Dostoyevsky\").\n"
        "5. Diminutives & Nicknames: Include widely accepted short forms (e.g., \"Bill Clinton\" -> \"William Jefferson Clinton\").\n"
        "6. Language: All aliases must be in English.\n"
        "7. Output: Return ONLY a JSON object with an \"aliases\" array containing unique, concise, and realistic string values. Do not include explanations."
    ),
    "chs": (
        "你是实体解析和名称标准化的专家。请为给定的人物名称生成全面且实用的别名列表，以提高搜索和匹配的准确性。\n"
        "规则：\n"
        "1. 完整姓名：包含官方的完整姓名（例如：\"爱因斯坦\" -> \"阿尔伯特·爱因斯坦\"）。\n"
        "2. 笔名与艺名：包含众所周知的笔名、艺名或化名（例如：\"鲁迅\" -> \"周树人\"）。\n"
        "3. 字号与尊称：对于历史人物，包含其字、号、谥号或广泛使用的尊称（例如：\"苏轼\" -> \"苏东坡\"、\"苏子瞻\"；\"甘地\" -> \"圣雄甘地\"）。\n"
        "4. 异译与拼写变体：包含常见的不同音译或写法（例如：\"笛卡尔\" -> \"笛卡儿\"、\"勒内·笛卡尔\"）。\n"
        "5. 简称与昵称：包含被广泛接受的缩写或简称。\n"
        "6. 语言：所有别名必须使用中文。\n"
        "7. 输出：仅返回包含 \"aliases\" 字符串数组的 JSON 对象。别名应简洁、真实、去重。不要包含任何解释。"
    ),
}


async def generate_souler_aliases(name: str, lang: Lang) -> list[str]:
    cleaned_name = name.strip()
    if not cleaned_name:
        return [name]

    payload = await complete_json(
        [
            {"role": "system", "content": ALIAS_PROMPT[lang]},
            {"role": "user", "content": f"Name: {cleaned_name}"},
        ],
        schema_name="souler_aliases",
        schema=ALIASES_SCHEMA,
        temperature=settings.MODEL_S_TEMPERATURE,
    )
    aliases_raw = payload.get("aliases") if isinstance(payload, dict) else None
    aliases = [str(item) for item in aliases_raw or [] if str(item).strip()]
    return normalize_aliases(cleaned_name, aliases)
