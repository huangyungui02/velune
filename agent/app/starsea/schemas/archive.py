from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel

from app.starsea.schemas.model import ResonanceMatch


class TextArchive(BaseModel):
    type: Literal["text"] = "text"
    role: Literal["user", "assistant"]
    content: str


class DivinationArchiveContent(BaseModel):
    casted_lines: list[int]
    date: str


class DivinationArchive(BaseModel):
    type: Literal["divination"] = "divination"
    role: Literal["user"] = "user"
    content: DivinationArchiveContent


class ResonanceMatchArchive(BaseModel):
    type: Literal["resonance_match"] = "resonance_match"
    role: Literal["assistant"] = "assistant"
    content: list[ResonanceMatch | dict[str, Any]]
