from __future__ import annotations

import operator
from typing import Annotated, Any, Literal, TypedDict

from langchain_core.messages import AnyMessage
from langgraph.graph.message import add_messages

RouterAction = Literal["starsea", "collect", "divination"]
UserInputType = Literal["text", "divination", "trigger"]


class GlimmerState(TypedDict):
    content: str
    keywords: list[str]
    blessing: str


class StarseaInputMetadata(TypedDict):
    timezone: str
    memory_enabled: bool


class StarseaStateMetadata(StarseaInputMetadata):
    lang: str
    user_id: str
    is_premium: bool


class ArchiveState(TypedDict):
    type: str
    role: str
    content: Any


class UserInputState(TypedDict):
    type: UserInputType
    content: Any


class State(TypedDict):
    user_input: UserInputState
    messages: Annotated[list[AnyMessage], add_messages]
    archives: Annotated[list[ArchiveState], operator.add]
    glimmer: GlimmerState | None
    metadata: StarseaStateMetadata
