from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Literal, TypedDict

from supabase import Client, create_client

from app.config import get_settings
from app.errors import CreditLimitError, UnauthorizedError

settings = get_settings()
supabase: Client = create_client(
    settings.SUPABASE_URL,
    settings.SUPABASE_SERVICE_ROLE_KEY,
)


Role = Literal["user", "assistant"]


class Souler(TypedDict):
    id: str
    name: str
    bio: str | None


class SessionContext(TypedDict):
    id: str
    soulerId: str
    title: str
    souler: Souler


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


def get_user_id_from_auth_header(authorization: str | None) -> str:
    if not authorization:
        raise UnauthorizedError("Unauthorized")

    pieces = authorization.split(" ", 1)
    if len(pieces) != 2:
        raise UnauthorizedError("Unauthorized")

    jwt = pieces[1].strip()
    if not jwt:
        raise UnauthorizedError("Unauthorized")

    user_response = supabase.auth.get_user(jwt)
    user = getattr(user_response, "user", None)
    user_id = getattr(user, "id", None)
    if not user_id:
        raise UnauthorizedError("Unauthorized")

    return str(user_id)


def _first_row(data: Any) -> dict[str, Any] | None:
    if isinstance(data, list):
        return data[0] if data else None
    if isinstance(data, dict):
        return data
    return None


def _to_souler(raw: Any) -> Souler:
    souler = raw[0] if isinstance(raw, list) and raw else raw
    if not isinstance(souler, dict):
        raise ValueError("Souler not found")

    souler_id = str(souler.get("id", "")).strip()
    name = str(souler.get("name", "")).strip()
    if not souler_id or not name:
        raise ValueError("Souler not found")

    bio = souler.get("bio")
    return {
        "id": souler_id,
        "name": name,
        "bio": str(bio) if isinstance(bio, str) else None,
    }


def update_glimmer_status(
    glimmer_id: str,
    status: Literal["processing", "complete", "incomplete", "failed"],
) -> None:
    supabase.table("glimmers").update({"status": status}).eq("id", glimmer_id).execute()


def get_glimmer_or_none(glimmer_id: str, user_id: str) -> dict[str, Any] | None:
    response = (
        supabase.table("glimmers")
        .select("*")
        .eq("id", glimmer_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )
    return _first_row(response.data)


def ensure_glimmer(user_id: str, glimmer_id: str, content: str) -> dict[str, Any]:
    existing = get_glimmer_or_none(glimmer_id, user_id)
    if existing:
        return existing

    insert_error: Exception | None = None
    try:
        (
            supabase.table("glimmers")
            .insert(
                {
                    "id": glimmer_id,
                    "user_id": user_id,
                    "content": content,
                }
            )
            .execute()
        )
    except Exception as error:  # noqa: BLE001
        insert_error = error

    created = get_glimmer_or_none(glimmer_id, user_id)
    if created:
        return created

    if insert_error:
        raise insert_error
    raise ValueError("Failed to ensure glimmer")


def list_glimmer_echoes(glimmer_id: str) -> list[dict[str, Any]]:
    response = (
        supabase.table("echoes_with_souler")
        .select("id, glimmer_id, souler_id, souler_name, content, created_at")
        .eq("glimmer_id", glimmer_id)
        .order("created_at")
        .execute()
    )
    data = response.data
    if not isinstance(data, list):
        return []
    return [row for row in data if isinstance(row, dict)]


def get_session_by_id(user_id: str, session_id: str) -> SessionContext:
    response = (
        supabase.table("sessions")
        .select("id, user_id, souler_id, title, soulers(id, name, bio)")
        .eq("id", session_id)
        .eq("user_id", user_id)
        .single()
        .execute()
    )

    row = _first_row(response.data)
    if not row:
        raise ValueError("Session not found")

    return {
        "id": str(row.get("id")),
        "soulerId": str(row.get("souler_id")),
        "title": str(row.get("title", "")),
        "souler": _to_souler(row.get("soulers")),
    }


def get_souler_by_id(souler_id: str) -> Souler:
    response = (
        supabase.table("soulers")
        .select("id, name, bio")
        .eq("id", souler_id)
        .single()
        .execute()
    )
    row = _first_row(response.data)
    if not row:
        raise ValueError("Souler not found")
    return _to_souler(row)


def get_echo_context(user_id: str, echo_id: str) -> EchoContext:
    response = (
        supabase.table("echoes")
        .select("id, souler_id, session_id, content, glimmers!inner(user_id, content)")
        .eq("id", echo_id)
        .eq("glimmers.user_id", user_id)
        .single()
        .execute()
    )
    row = _first_row(response.data)
    if not row:
        raise ValueError("Echo not found")

    glimmer = row.get("glimmers")
    glimmer_row = glimmer[0] if isinstance(glimmer, list) and glimmer else glimmer
    if not isinstance(glimmer_row, dict):
        raise ValueError("Echo not found")

    return {
        "id": str(row.get("id", "")),
        "souler_id": str(row.get("souler_id", "")),
        "session_id": str(row.get("session_id")) if row.get("session_id") else None,
        "content": str(row.get("content", "")),
        "glimmer_content": str(glimmer_row.get("content", "")),
    }


def bind_echo_session_if_missing(
    user_id: str,
    echo_id: str,
    session_id: str,
) -> str:
    echo_context = get_echo_context(user_id, echo_id)
    existing_session_id = echo_context.get("session_id")
    if existing_session_id:
        return existing_session_id

    response = (
        supabase.table("echoes")
        .update({"session_id": session_id}, returning="representation")
        .eq("id", echo_id)
        .is_("session_id", "null")
        .execute()
    )
    row = _first_row(response.data)
    updated_session_id = str(row.get("session_id")) if row and row.get("session_id") else None
    if updated_session_id:
        return updated_session_id

    refreshed = get_echo_context(user_id, echo_id)
    if refreshed.get("session_id"):
        return str(refreshed["session_id"])

    raise ValueError("Failed to bind echo session")


def create_session(user_id: str, souler_id: str, title: str = "") -> str:
    response = (
        supabase.table("sessions")
        .insert(
            {
                "user_id": user_id,
                "souler_id": souler_id,
                "title": title,
            },
            returning="representation",
        )
        .execute()
    )
    row = _first_row(response.data)
    if not row or not row.get("id"):
        raise ValueError("Failed to create session")
    return str(row["id"])


def delete_session(user_id: str, session_id: str) -> None:
    (
        supabase.table("sessions")
        .delete()
        .eq("id", session_id)
        .eq("user_id", user_id)
        .execute()
    )


def update_session_title(user_id: str, session_id: str, title: str) -> None:
    (
        supabase.table("sessions")
        .update({"title": title})
        .eq("id", session_id)
        .eq("user_id", user_id)
        .execute()
    )


def touch_session(user_id: str, session_id: str) -> None:
    (
        supabase.table("sessions")
        .update({"updated_at": datetime.now(timezone.utc).isoformat()})
        .eq("id", session_id)
        .eq("user_id", user_id)
        .execute()
    )


def get_recent_messages(user_id: str, session_id: str) -> list[MessageRow]:
    response = (
        supabase.table("messages")
        .select("id, user_id, souler_id, session_id, role, content, created_at")
        .eq("user_id", user_id)
        .eq("session_id", session_id)
        .order("created_at", desc=True)
        .limit(20)
        .execute()
    )

    rows = response.data if isinstance(response.data, list) else []
    rows.reverse()
    return rows  # type: ignore[return-value]


def insert_message(
    user_id: str,
    souler_id: str,
    session_id: str,
    role: Role,
    content: str,
) -> dict[str, str]:
    response = (
        supabase.table("messages")
        .insert(
            {
                "user_id": user_id,
                "souler_id": souler_id,
                "session_id": session_id,
                "role": role,
                "content": content,
            },
            returning="representation",
        )
        .execute()
    )

    row = _first_row(response.data)
    if not row:
        raise ValueError("Failed to create message")

    return {
        "id": str(row.get("id", "")),
        "created_at": str(row.get("created_at", "")),
    }


def _parse_credit_consumption_row(row: dict[str, Any]) -> None:
    ok = bool(row.get("ok"))

    if not ok:
        message = str(row.get("message", "Not enough credits for this request"))
        code = str(row.get("code", "INSUFFICIENT_CREDITS"))
        raise CreditLimitError(
            message,
            code,
        )


def _consume_credit_rpc(
    rpc_name: str,
    payload: dict[str, Any],
    *,
    missing_row_error: str,
) -> None:
    response = supabase.rpc(rpc_name, payload).execute()
    row = _first_row(response.data)
    if not row:
        raise ValueError(missing_row_error)
    _parse_credit_consumption_row(row)


def consume_stardust(
    user_id: str,
    amount: int,
) -> None:
    _consume_credit_rpc(
        "consume_stardust",
        payload={
            "p_user_id": user_id,
            "p_cost": amount,
        },
        missing_row_error="Failed to consume stardust",
    )


def consume_echo_credit(
    user_id: str,
    amount: int = 5,
) -> None:
    _consume_credit_rpc(
        "consume_stardust",
        payload={
            "p_user_id": user_id,
            "p_cost": amount,
        },
        missing_row_error="Failed to consume echo credit",
    )


def consume_chat_credit(
    user_id: str,
) -> None:
    _consume_credit_rpc(
        "consume_chat_credit",
        payload={
            "p_user_id": user_id,
        },
        missing_row_error="Failed to consume chat credit",
    )


def refund_stardust(
    user_id: str,
    amount: int,
) -> None:
    _consume_credit_rpc(
        "refund_stardust",
        payload={
            "p_user_id": user_id,
            "p_amount": amount,
        },
        missing_row_error="Failed to refund stardust",
    )


def create_or_update_resonance(
    user_id: str,
    souler_id: str,
    last_session_id: str | None,
    last_session_title: str,
) -> None:
    supabase.rpc(
        "touch_resonance",
        {
            "p_user_id": user_id,
            "p_souler_id": souler_id,
            "p_last_session_id": last_session_id,
            "p_last_session_title": last_session_title,
        },
    ).execute()


def get_souler_by_name(candidate_name: str, lang: str) -> dict[str, Any] | None:
    query = candidate_name.strip()
    query_lang = lang.strip()
    if not query or not query_lang:
        return None

    response = (
        supabase.table("soulers")
        .select("*")
        .eq("name", query)
        .eq("lang", query_lang)
        .limit(1)
        .execute()
    )
    return _first_row(response.data)


def get_souler_by_alias(candidate_name: str, lang: str) -> dict[str, Any] | None:
    query = candidate_name.strip()
    query_lang = lang.strip()
    if not query or not query_lang:
        return None

    alias_response = (
        supabase.table("souler_aliases")
        .select("soulers!inner(*)")
        .eq("alias", query)
        .eq("soulers.lang", query_lang)
        .limit(1)
        .execute()
    )
    alias_row = _first_row(alias_response.data)
    if not alias_row:
        return None

    return _first_row(alias_row.get("soulers"))


def create_souler(name: str, lang: str) -> dict[str, Any]:
    cleaned_name = name.strip()
    cleaned_lang = lang.strip()
    if not cleaned_name:
        raise ValueError("Souler name cannot be empty")
    if not cleaned_lang:
        raise ValueError("Souler lang cannot be empty")

    response = (
        supabase.table("soulers")
        .insert(
            {
                "name": cleaned_name,
                "lang": cleaned_lang,
            },
            returning="representation",
        )
        .execute()
    )

    row = _first_row(response.data)
    if not row:
        raise ValueError("Failed to create souler")
    return row


def add_souler_alias(souler_id: str, souler_name: str, alias: str, lang: str) -> None:
    cleaned_alias = alias.strip()
    if not cleaned_alias:
        return

    if souler_name.strip() == cleaned_alias:
        return

    existing = get_souler_by_alias(cleaned_alias, lang)
    if existing:
        return

    try:
        (
            supabase.table("souler_aliases")
            .insert(
                {
                    "souler_id": souler_id,
                    "alias": cleaned_alias,
                }
            )
            .execute()
        )
    except Exception:  # noqa: BLE001
        # Alias can collide across languages under the current global unique constraint.
        return


def update_souler(souler_id: str, data: dict[str, Any]) -> dict[str, Any]:
    response = (
        supabase.table("soulers")
        .update(data, returning="representation")
        .eq("id", souler_id)
        .execute()
    )

    row = _first_row(response.data)
    if not row:
        raise ValueError("Failed to update souler")
    return row


def create_echo(
    glimmer_id: str,
    souler_id: str,
    content: str,
) -> dict[str, Any]:
    response = (
        supabase.table("echoes")
        .insert(
            {
                "glimmer_id": glimmer_id,
                "souler_id": souler_id,
                "content": content,
            },
            returning="representation",
        )
        .execute()
    )

    row = _first_row(response.data)
    if not row:
        raise ValueError("Failed to create echo")
    return row


def insert_session_message(
    user_id: str,
    souler_id: str,
    session_id: str,
    role: Role,
    content: str,
) -> None:
    (
        supabase.table("messages")
        .insert(
            {
                "user_id": user_id,
                "souler_id": souler_id,
                "session_id": session_id,
                "role": role,
                "content": content,
            }
        )
        .execute()
    )
