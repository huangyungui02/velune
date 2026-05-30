from __future__ import annotations

from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.services.chat.preferences import DEFAULT_REPLY_LENGTH, ReplyLength, normalize_reply_length


class ChatRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    session_id: str | None = Field(default=None, alias="sessionId")
    souler_id: str | None = Field(default=None, alias="soulerId")
    chapter_id: str | None = Field(default=None, alias="chapterId")
    content: str
    reply_length: ReplyLength = Field(default=DEFAULT_REPLY_LENGTH, alias="replyLength")

    @field_validator("session_id", "souler_id", "chapter_id")
    @classmethod
    def validate_uuid(cls, value: str | None) -> str:
        trimmed = str(value or "").strip()
        if not trimmed:
            return ""
        return str(UUID(trimmed))

    @field_validator("reply_length", mode="before")
    @classmethod
    def validate_reply_length(cls, value: Any) -> ReplyLength:
        return normalize_reply_length(value)

    @field_validator("content")
    @classmethod
    def clean_content(cls, value: str) -> str:
        content = value.strip()
        if not content:
            raise ValueError("Missing content")
        return content

    @property
    def cleaned_content(self) -> str:
        return self.content
