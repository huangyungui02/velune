from __future__ import annotations

from typing import Literal

from pydantic import TypeAdapter

Lang = Literal["en", "zh"]
LANG_ADAPTER = TypeAdapter(Lang)


def validate_lang(value: str) -> Lang:
    return LANG_ADAPTER.validate_python(value.strip().lower())
