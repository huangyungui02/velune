from __future__ import annotations

from typing import Literal

from pydantic import BaseModel

from app.starsea.schemas.model import (
    DeltaContent,
    DoneContent,
    ErrorContent,
    OptionContent,
    ReadyContent,
    ResonanceMatchContent,
    SettledContent,
)


class DeltaEvent(BaseModel):
    type: Literal["delta"] = "delta"
    content: DeltaContent


class ReadyEvent(BaseModel):
    type: Literal["ready"] = "ready"
    content: ReadyContent


class ResonanceMatchEvent(BaseModel):
    type: Literal["resonance_match"] = "resonance_match"
    content: ResonanceMatchContent


class OptionEvent(BaseModel):
    type: Literal["option"] = "option"
    content: OptionContent


class SettledEvent(BaseModel):
    type: Literal["settled"] = "settled"
    content: SettledContent


class DoneEvent(BaseModel):
    type: Literal["done"] = "done"
    content: DoneContent


class ErrorEvent(BaseModel):
    type: Literal["error"] = "error"
    content: ErrorContent


StarseaEvent = (
    DeltaEvent
    | ReadyEvent
    | ResonanceMatchEvent
    | OptionEvent
    | SettledEvent
    | DoneEvent
    | ErrorEvent
)
