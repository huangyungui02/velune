from __future__ import annotations

from typing import Literal

from app.core.lang import Lang

ReplyLength = Literal["standard", "concise"]


def normalize_reply_length(value: object) -> ReplyLength:
    return "concise" if value == "concise" else "standard"


def apply_reply_length_prompt(
    system_prompt: str,
    lang: Lang,
    reply_length: ReplyLength,
) -> str:
    if reply_length != "concise":
        return system_prompt

    instruction: dict[Lang, str] = {
        "zh": "回复长度偏好：用户选择了简洁。请保持回复简洁明了，优先回应核心内容，避免铺陈和重复，将AI生成内容控制在300字以内。",
        "en": "Reply length preference: the user chose concise. Keep replies short and focused, answer the core point first, and avoid elaboration or repetition. Keep AI-generated content under 300 words.",
    }
    return f"{system_prompt}\n\n{instruction[lang]}"
