from __future__ import annotations

import operator
from typing import Annotated, Any, Literal, TypedDict

from langchain_core.messages import AnyMessage
from langgraph.graph.message import add_messages

RouterAction = Literal["starsea", "collect"]


class ArchiveEvent(TypedDict):
    type: str
    role: str | None
    content: str | None
    data: dict[str, Any]


class GlimmerState(TypedDict):
    content: str
    keywords: list[str]
    blessing: str


class State(TypedDict):
    messages: Annotated[list[AnyMessage], add_messages]
    archive_events: Annotated[list[ArchiveEvent], operator.add]
    glimmer: GlimmerState | None
    metadata: dict[str, Any]
