from __future__ import annotations

from dataclasses import dataclass

from app.core import Lang
from app.domain import Session


@dataclass(frozen=True)
class PreparedChat:
    user_id: str
    session: Session
    lang: Lang
    content: str
    is_new_session: bool
    should_generate_title: bool
    prompt_messages: list[dict[str, str]]
