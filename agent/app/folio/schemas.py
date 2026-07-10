from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class FolioMessageRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    session_id: str = Field(alias="sessionId")
    content: str

    @field_validator("session_id")
    @classmethod
    def validate_session_id(cls, value: str) -> str:
        return str(UUID(value.strip()))

    @field_validator("content")
    @classmethod
    def clean_content(cls, value: str) -> str:
        content = value.strip()
        if not content:
            raise ValueError("Missing content")
        return content
