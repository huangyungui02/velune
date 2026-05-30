from __future__ import annotations

from dataclasses import dataclass

from app.schemas.common import Lang
from app.schemas.entities import Session


@dataclass(frozen=True)
class PreparedChat:
    user_id: str
    session: Session
    lang: Lang
    content: str
    is_new_session: bool
    should_generate_title: bool
    prompt_messages: list[dict[str, str]]
