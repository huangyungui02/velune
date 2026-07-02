from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ReadyContent(BaseModel):
    thread_id: str


class DeltaContent(BaseModel):
    delta: str = Field(min_length=1)
    display_type: Literal["starsea", "thinking", "thinking_summary", "collect"]


class OptionContent(BaseModel):
    options: list[str] = Field(min_length=3, max_length=3)

    @field_validator("options")
    @classmethod
    def require_options(cls, options: list[str]) -> list[str]:
        if any(not option.strip() for option in options):
            raise ValueError("options must be non-empty")
        return options


class ResonanceMatch(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    name: str
    whisper: str
    resolution_status: str = Field(alias="resolutionStatus")
    souler_id: str | None = Field(default=None, alias="soulerId")
    resolution_request_id: str | None = Field(default=None, alias="resolutionRequestId")


class ResonanceMatchContent(BaseModel):
    matches: list[ResonanceMatch]


class GlimmerContent(BaseModel):
    content: str
    keywords: list[str]
    blessing: str | None = None


class SettledContent(BaseModel):
    thread_id: str
    glimmer: GlimmerContent


class DoneContent(BaseModel):
    thread_id: str


class ErrorContent(BaseModel):
    message: str
