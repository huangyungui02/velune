from .auth import get_user_id_from_auth_header
from .catalog import get_chapter_by_id, get_souler_by_id
from .chapter_generation import (
    complete_souler_chapters_generation,
    start_souler_chapters_generation,
)
from .credit import (
    consume_stardust,
    refund_stardust,
)
from .echo import bind_echo_session_if_missing, create_echo, get_echo_context
from .glimmer import ensure_glimmer, get_glimmer_or_none, list_glimmer_echoes, update_glimmer_status
from .messages import get_recent_messages, insert_message, insert_session_message
from .resonance import create_or_update_resonance
from .session import (
    create_session,
    delete_session,
    get_session_by_id,
    touch_session,
    update_session_title,
)
from .soulers import (
    add_souler_alias,
    create_souler,
    get_souler_by_alias,
    get_souler_by_name,
    mark_chapters_generation_failed,
    update_souler,
)
from .types import ChapterContext, EchoContext, MessageRow, Role, SessionContext, Souler

__all__ = [
    "Role",
    "Souler",
    "ChapterContext",
    "SessionContext",
    "MessageRow",
    "EchoContext",
    "get_user_id_from_auth_header",
    "update_glimmer_status",
    "get_glimmer_or_none",
    "ensure_glimmer",
    "list_glimmer_echoes",
    "get_session_by_id",
    "get_souler_by_id",
    "get_chapter_by_id",
    "get_echo_context",
    "bind_echo_session_if_missing",
    "create_session",
    "start_souler_chapters_generation",
    "complete_souler_chapters_generation",
    "mark_chapters_generation_failed",
    "delete_session",
    "update_session_title",
    "touch_session",
    "get_recent_messages",
    "insert_message",
    "consume_stardust",
    "refund_stardust",
    "create_or_update_resonance",
    "get_souler_by_name",
    "get_souler_by_alias",
    "create_souler",
    "add_souler_alias",
    "update_souler",
    "create_echo",
    "insert_session_message",
]
