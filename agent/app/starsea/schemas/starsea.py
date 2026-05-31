from __future__ import annotations

from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class StarseaRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    content: str | None = None
    metadata: dict[str, Any] | None = None
    thread_id: str | None = Field(default=None, alias="threadId")
    intent: Literal["collect"] | None = None

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
    def safe_metadata(self) -> dict[str, Any]:
        return self.metadata or {}
