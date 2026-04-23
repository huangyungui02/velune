from __future__ import annotations

from app.llm import complete_json
from app.shared import Lang

CANONICAL_NAME_MODEL = "qwen3.5-flash"
CANONICAL_NAME_TEMPERATURE = 0.25
CANONICAL_NAME_SCHEMA = {
    "type": "object",
    "properties": {
        "canonical_name": {
            "type": "string",
        }
    },
    "required": ["canonical_name"],
    "additionalProperties": False,
}
CANONICAL_NAME_PROMPT: dict[Lang, str] = {
    "en": (
        "## Task\n"
        "Given a person name, return a canonical person name, as JSON format.\n\n"
        "## Example Input\n"
        "Nietzsche\n\n"
        "## Example Output\n"
        '{"canonical_name":"Friedrich Nietzsche"}'
    ),
    "zh": (
        "## Task\n"
        "将给定人物名，返回为规范人物名，以JSON格式返回\n\n"
        "## Example Input\n"
        "尼采\n\n"
        "## Example Output\n"
        '{"canonical_name":"弗里德里希·尼采"}'
    ),
}


async def canonicalize_souler_name(name: str, lang: Lang) -> str:
    cleaned_name = name.strip()
    if not cleaned_name:
        raise ValueError("Souler name cannot be empty")

    prompt = CANONICAL_NAME_PROMPT["zh" if lang == "zh" else "en"]
    payload = await complete_json(
        [
            {"role": "system", "content": prompt},
            {"role": "user", "content": cleaned_name},
        ],
        model=CANONICAL_NAME_MODEL,
        schema_name="canonical_souler_name",
        schema=CANONICAL_NAME_SCHEMA,
        temperature=CANONICAL_NAME_TEMPERATURE,
    )
    if not isinstance(payload, dict):
        raise ValueError("Invalid canonical name response")

    canonical_name = str(payload.get("canonical_name", "")).strip()
    if not canonical_name:
        raise ValueError("Canonical souler name is empty")

    return canonical_name
