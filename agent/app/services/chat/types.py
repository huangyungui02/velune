from __future__ import annotations

from dataclasses import dataclass

from app.core.lang import Lang
from app.repositories import SessionContext


@dataclass(frozen=True)
class PreparedChat:
    user_id: str
    session: SessionContext
    lang: Lang
    content: str
    is_new_session: bool
    should_generate_title: bool
    prompt_messages: list[dict[str, str]]
