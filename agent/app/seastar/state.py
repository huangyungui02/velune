from __future__ import annotations

import operator
from typing import Annotated, Any, Literal, TypedDict

from langchain_core.messages import AnyMessage
from langgraph.graph.message import add_messages

RouterAction = Literal["starsea", "collect"]


class ThoughtMatchPreview(TypedDict, total=False):
    name: str
    line: str
    soulerId: str | None
    resolutionRequestId: str | None
    resolutionStatus: str | None


class StarseaDisplay(TypedDict):
    type: Literal["starsea"]
    content: str
    resonance_matches: list[ThoughtMatchPreview]


class CollectDisplay(TypedDict):
    type: Literal["collect"]
    content: str


class GlimmerDisplay(TypedDict):
    type: Literal["glimmer"]
    glimmer: dict[str, str]


Display = StarseaDisplay | CollectDisplay | GlimmerDisplay


class ArchiveEvent(TypedDict):
    type: str
    role: str | None
    content: str | None
    payload: dict[str, Any]


class State(TypedDict):
    messages: Annotated[list[AnyMessage], add_messages]
    display: Display | None
    archive_events: Annotated[list[ArchiveEvent], operator.add]
    pending_glimmer: str | None
    confirmed_glimmer: str | None
    created_glimmer_id: str | None
    metadata: dict[str, Any]
