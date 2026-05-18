from __future__ import annotations

from typing import Any

FLOW_MODEL = "qwen3.5-flash"

THEME_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "keywords": {
            "type": "array",
            "minItems": 3,
            "maxItems": 6,
            "items": {"type": "string"},
        }
    },
    "required": ["keywords"],
    "additionalProperties": False,
}

RESONANCE_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "figures": {
            "type": "array",
            "minItems": 5,
            "maxItems": 5,
            "items": {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "reason": {"type": "string"},
                },
                "required": ["name", "reason"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["figures"],
    "additionalProperties": False,
}
