from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class StarseaGraphEvent(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    event: str = ""
    thread_id: str = Field(default="", alias="thread_id")
    data: Any = None


class MessageDeltaData(BaseModel):
    delta: str = ""


class CompletedData(BaseModel):
    display: Any = None


class ErrorData(BaseModel):
    message: str = "Starsea failed"

    @model_validator(mode="after")
    def ensure_message(self) -> ErrorData:
        self.message = self.message or "Starsea failed"
        return self


class ResonanceMatchPreview(BaseModel):
    name: str
    line: str = ""

    @model_validator(mode="before")
    @classmethod
    def normalize_whisper(cls, value: Any) -> Any:
        if isinstance(value, dict) and not value.get("line") and value.get("whisper"):
            return {**value, "line": value["whisper"]}
        return value

    @model_validator(mode="after")
    def clean_text(self) -> ResonanceMatchPreview:
        self.name = self.name.strip()
        self.line = self.line.strip()
        if not self.name or not self.line:
            raise ValueError("name and line are required")
        return self


class SoulerResolutionResult(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    status: str = ""
    souler_id: str | None = Field(default=None, alias="soulerId")
    request_id: str | None = Field(default=None, alias="requestId")


class ResonanceMatchPayload(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    name: str
    line: str
    resolution_status: str = Field(alias="resolutionStatus")
    souler_id: str | None = Field(default=None, alias="soulerId")
    resolution_request_id: str | None = Field(default=None, alias="resolutionRequestId")


class DeltaPayload(BaseModel):
    type: Literal["delta"] = "delta"
    delta: str


class ReadyPayload(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    type: Literal["ready"] = "ready"
    thread_id: str = Field(alias="threadId")


class StarseaMatchesPayload(BaseModel):
    type: Literal["resonance_match"] = "resonance_match"
    matches: list[ResonanceMatchPayload]


class SettledPayload(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    type: Literal["settled"] = "settled"
    thread_id: str = Field(alias="threadId")
    glimmer: dict[str, Any]


class DonePayload(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    type: Literal["done"] = "done"
    thread_id: str = Field(alias="threadId")
    display: Any = None


class ErrorPayload(BaseModel):
    type: Literal["error"] = "error"
    message: str


class UnknownEventPayload(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    type: Literal["event"] = "event"
    thread_id: str = Field(alias="threadId")
    data: Any = None
