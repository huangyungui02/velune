from __future__ import annotations

from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, Field, field_validator

from app.starsea.state import StarseaInputMetadata


class TextContent(BaseModel):
    type: Literal["text"]
    content: str

    @field_validator("content")
    @classmethod
    def clean_content(cls, value: str) -> str:
        content = value.strip()
        if not content:
            raise ValueError("content cannot be empty")
        return content


class DivinationContent(BaseModel):
    casted_lines: list[int] = Field(alias="casted_lines")
    date: datetime
    question: str

    @field_validator("casted_lines")
    @classmethod
    def validate_casted_lines(cls, value: list[int]) -> list[int]:
        if len(value) != 6:
            raise ValueError("casted_lines must contain exactly 6 lines")
        if any(line not in {0, 1, 2, 3} for line in value):
            raise ValueError("casted_lines values must be 0, 1, 2, or 3")
        return value

    @field_validator("question")
    @classmethod
    def clean_required_text(cls, value: str) -> str:
        content = value.strip()
        if not content:
            raise ValueError("divination question cannot be empty")
        return content


class DivinationEnvelope(BaseModel):
    type: Literal["divination"]
    content: DivinationContent


class TriggerContent(BaseModel):
    type: Literal["trigger"]
    content: Literal["collect"]


StarseaContent = Annotated[
    TextContent | DivinationEnvelope | TriggerContent,
    Field(discriminator="type"),
]


class StarseaMetadata(BaseModel):
    timezone: str
    memory_enabled: bool = False

    @field_validator("timezone")
    @classmethod
    def clean_timezone(cls, value: str) -> str:
        timezone = value.strip()
        if not timezone or timezone.lower() == "unknown":
            raise ValueError("timezone is required")
        try:
            ZoneInfo(timezone)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("timezone must be a valid IANA timezone") from exc
        return timezone


class StarseaRequest(BaseModel):
    content: StarseaContent
    thread_id: str | None = None
    metadata: StarseaMetadata

    @field_validator("thread_id")
    @classmethod
    def validate_thread_id(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return str(UUID(str(value)))

    @property
    def runtime_metadata(self) -> StarseaInputMetadata:
        return {
            "timezone": self.metadata.timezone,
            "memory_enabled": self.metadata.memory_enabled,
        }
