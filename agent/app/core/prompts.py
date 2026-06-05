from __future__ import annotations

from app.core.common import Lang, validate_lang

LANGUAGE_NAMES: dict[Lang, str] = {
    "zh": "简体中文",
    "en": "English",
}

LANGUAGE_PROMPT = """
# 语言
当前用户系统设置语言：{language_name}
你应优先使用当前用户输入的语言，其次参考用户系统设置语言。
"""


def apply_prompt_lang(prompt: str, lang: str) -> str:
    normalized_lang = validate_lang(lang)
    language_prompt = LANGUAGE_PROMPT.format(
        language_name=LANGUAGE_NAMES[normalized_lang]
    ).strip()
    return f"{prompt.rstrip()}\n\n{language_prompt}"
