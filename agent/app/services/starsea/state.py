from __future__ import annotations

from typing import Annotated, Any, Literal, TypedDict

from langchain_core.messages import AnyMessage
from langgraph.graph.message import add_messages

RouterAction = Literal["starsea", "collect"]


class ThoughtMatchPreview(TypedDict):
    name: str
    line: str


class StarseaDisplay(TypedDict):
    type: Literal["starsea"]
    content: str
    resonance_matches: list[ThoughtMatchPreview]


class CollectDisplay(TypedDict):
    type: Literal["collect"]
    content: str


Display = StarseaDisplay | CollectDisplay


class State(TypedDict):
    messages: Annotated[list[AnyMessage], add_messages]
    display: Display | None
    metadata: dict[str, Any]
