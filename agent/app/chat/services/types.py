from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass

from app.core.common import Lang
from app.core.entities import Session

StageLogger = Callable[[str], None]


@dataclass(frozen=True)
class PreparedChat:
    user_id: str
    session: Session
    lang: Lang
    content: str
    model: str
    is_new_session: bool
    should_generate_title: bool
    prompt_messages: list[dict[str, str]]


@dataclass(frozen=True)
class SessionResolution:
    session: Session
    is_new: bool
    should_generate_title: bool
