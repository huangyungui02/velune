from __future__ import annotations

from typing import Literal, TypedDict

Role = Literal["user", "assistant"]


class Souler(TypedDict):
    id: str
    name: str
    bio: str | None


class Chapter(TypedDict):
    id: str
    souler_id: str
    seq: int
    title: str
    subtitle: str
    task: str


class Session(TypedDict):
    id: str
    souler_id: str
    title: str
    souler: Souler
    chapter: Chapter | None


class Message(TypedDict):
    id: str
    user_id: str
    souler_id: str
    session_id: str | None
    role: Role
    content: str
    created_at: str
