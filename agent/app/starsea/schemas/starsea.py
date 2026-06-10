from __future__ import annotations

from typing import Any, Literal
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class StarseaRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    content: str | None = None
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

    @field_validator("content")
    @classmethod
    def clean_content(cls, value: str | None) -> str | None:
        return value.strip() if isinstance(value, str) else value

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
        if self.intent != "collect" and not self.cleaned_content:
            raise ValueError("content cannot be empty")
        return self

    @property
    def cleaned_content(self) -> str:
        return self.content or ""

    @property
    def runtime_metadata(self) -> dict[str, Any]:
        metadata: dict[str, Any] = {}
        if self.timezone:
            metadata["timezone"] = self.timezone
        metadata["memoryEnabled"] = self.memory_enabled
        return metadata
