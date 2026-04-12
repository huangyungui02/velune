from __future__ import annotations

from typing import Literal, TypedDict

Role = Literal["user", "assistant"]


class Souler(TypedDict):
    id: str
    name: str
    bio: str | None


class ChapterContext(TypedDict):
    id: str
    souler_id: str
    seq: int
    title: str
    subtitle: str
    role: str
    task: str


class SessionContext(TypedDict):
    id: str
    soulerId: str
    title: str
    souler: Souler
    chapter: ChapterContext | None


class MessageRow(TypedDict):
    id: str
    user_id: str
    souler_id: str
    session_id: str | None
    role: Role
    content: str
    created_at: str


class EchoContext(TypedDict):
    id: str
    souler_id: str
    session_id: str | None
    content: str
    glimmer_content: str
