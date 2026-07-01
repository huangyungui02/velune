from __future__ import annotations

from datetime import datetime
from typing import Annotated, Any, Literal
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


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

    @property
    def archive_content(self) -> dict[str, Any]:
        return {
            "casted_lines": self.casted_lines,
            "date": self.date.isoformat(),
        }


class DivinationEnvelope(BaseModel):
    type: Literal["divination"]
    content: DivinationContent


StarseaContent = Annotated[TextContent | DivinationEnvelope, Field(discriminator="type")]


class StarseaRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    content: StarseaContent | None = None
    metadata: dict[str, Any] | None = None
    thread_id: str | None = Field(default=None, alias="threadId")
    intent: Literal["collect"] | None = None
    timezone: str | None = None
    memory_enabled: bool = Field(default=False, alias="memoryEnabled")

    @model_validator(mode="before")
    @classmethod
    def apply_metadata_compatibility(cls, data: Any) -> Any:
        if not isinstance(data, dict):
            return data

        metadata = data.get("metadata")
        if not isinstance(metadata, dict):
            return data

        values = dict(data)
        if "timezone" not in values and "timezone" in metadata:
            values["timezone"] = metadata["timezone"]
        if "memoryEnabled" not in values and "memory_enabled" not in values:
            if "memoryEnabled" in metadata:
                values["memoryEnabled"] = metadata["memoryEnabled"]
        return values

    @field_validator("thread_id")
    @classmethod
    def validate_thread_id(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return str(UUID(str(value)))

    @field_validator("content", mode="before")
    @classmethod
    def normalize_content(cls, value: Any) -> Any:
        if isinstance(value, str):
            return {"type": "text", "content": value}
        return value

    @field_validator("timezone")
    @classmethod
    def clean_timezone(cls, value: str | None) -> str | None:
        timezone = value.strip() if isinstance(value, str) else None
        if not timezone or timezone.lower() == "unknown":
            return None
        try:
            ZoneInfo(timezone)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("timezone must be a valid IANA timezone") from exc
        return timezone

    @model_validator(mode="after")
    def validate_intent_content(self) -> StarseaRequest:
        if self.intent == "collect" and self.thread_id is None:
            raise ValueError("threadId is required when intent is collect")
        if self.intent != "collect" and self.content is None:
            raise ValueError("content cannot be empty")
        return self

    @property
    def content_type(self) -> str | None:
        return self.content.type if self.content is not None else None

    @property
    def runtime_metadata(self) -> dict[str, Any]:
        metadata: dict[str, Any] = {}
        if self.timezone:
            metadata["timezone"] = self.timezone
        metadata["memoryEnabled"] = self.memory_enabled
        if self.content_type:
            metadata["contentType"] = self.content_type
        return metadata
