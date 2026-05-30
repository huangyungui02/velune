from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.services.chat.preferences import DEFAULT_REPLY_LENGTH, ReplyLength, normalize_reply_length


class ChapterStartRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    reply_length: ReplyLength = Field(default=DEFAULT_REPLY_LENGTH, alias="replyLength")

    @field_validator("reply_length", mode="before")
    @classmethod
    def validate_reply_length(cls, value: Any) -> ReplyLength:
        return normalize_reply_length(value)
