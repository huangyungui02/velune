from __future__ import annotations

import operator
from typing import Annotated, Any, Literal, TypedDict

from langchain_core.messages import AnyMessage
from langgraph.graph.message import add_messages

RouterAction = Literal["starsea", "collect", "divination"]


class GlimmerState(TypedDict):
    content: str
    keywords: list[str]
    blessing: str


class State(TypedDict):
    user_input: dict[str, Any]
    messages: Annotated[list[AnyMessage], add_messages]
    archives: Annotated[list[dict[str, Any]], operator.add]
    glimmer: GlimmerState | None
    metadata: dict[str, Any]
