from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Literal, TypedDict

from supabase import Client, create_client

from app.config import get_settings
from app.errors import CreditLimitError, CreditState, UnauthorizedError

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
    prompt: str | None


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
    prompt = souler.get("prompt")

    return {
        "id": souler_id,
        "name": name,
        "bio": str(bio) if isinstance(bio, str) else None,
        "prompt": str(prompt) if isinstance(prompt, str) else None,
    }


def check_status_before_processing(glimmer_id: str) -> None:
    response = (
        supabase.table("glimmers").select("status").eq("id", glimmer_id).single().execute()
    )
    row = _first_row(response.data)
    status = row.get("status") if row else None
    if status != "pending":
        raise ValueError("Glimmer is not pending")


def update_glimmer_status(
    glimmer_id: str,
    status: Literal["processing", "complete", "incomplete", "failed"],
) -> None:
    supabase.table("glimmers").update({"status": status}).eq("id", glimmer_id).execute()


def get_glimmer(glimmer_id: str, user_id: str) -> dict[str, Any]:
    response = (
        supabase.table("glimmers")
        .select("*")
        .eq("id", glimmer_id)
        .eq("user_id", user_id)
        .single()
        .execute()
    )
    row = _first_row(response.data)
    if not row:
        raise ValueError("Glimmer not found")
    return row


def get_session_by_id(user_id: str, session_id: str) -> SessionContext:
    response = (
        supabase.table("sessions")
        .select("id, user_id, souler_id, title, soulers(id, name, bio, prompt)")
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
        .select("id, name, bio, prompt")
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
        .select("id, souler_id, content, glimmers!inner(user_id, content)")
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
        "content": str(row.get("content", "")),
        "glimmer_content": str(glimmer_row.get("content", "")),
    }


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


def consume_user_credit(user_id: str) -> CreditState:
    response = supabase.rpc("consume_user_credit", {"p_user_id": user_id}).execute()

    row = _first_row(response.data)
    if not row:
        raise ValueError("Failed to consume credit")

    plan = str(row.get("plan", "free"))
    monthly_limit = int(row.get("monthly_limit", 50))
    credits_remaining = int(row.get("credits_remaining", 0))
    ok = bool(row.get("ok"))

    if not ok:
        message = str(row.get("message", "Not enough credits for this request"))
        code = str(row.get("code", "INSUFFICIENT_CREDITS"))
        raise CreditLimitError(
            message,
            code,
            plan,
            monthly_limit,
            credits_remaining,
        )

    return CreditState(
        plan=plan,
        monthly_limit=monthly_limit,
        credits_remaining=credits_remaining,
    )


def create_or_update_resonance(
    user_id: str,
    souler_id: str,
    last_session_id: str | None,
    last_session_title: str,
) -> None:
    response = (
        supabase.table("resonances")
        .select("id, count")
        .eq("user_id", user_id)
        .eq("souler_id", souler_id)
        .limit(1)
        .execute()
    )

    row = _first_row(getattr(response, "data", None))
    if not row:
        (
            supabase.table("resonances")
            .insert(
                {
                    "user_id": user_id,
                    "souler_id": souler_id,
                    "last_session_id": last_session_id,
                    "last_session_title": last_session_title,
                    "count": 1,
                }
            )
            .execute()
        )
        return

    (
        supabase.table("resonances")
        .update(
            {
                "last_session_id": last_session_id,
                "last_session_title": last_session_title,
                "count": int(row.get("count", 0)) + 1,
            }
        )
        .eq("id", row.get("id"))
        .execute()
    )


def get_souler_by_name(candidate_name: str) -> dict[str, Any] | None:
    query = candidate_name.strip()
    if not query:
        return None

    response = (
        supabase.table("soulers")
        .select("*")
        .eq("name", query)
        .limit(1)
        .execute()
    )
    return _first_row(response.data)


def get_souler_by_alias(candidate_name: str) -> dict[str, Any] | None:
    query = candidate_name.strip()
    if not query:
        return None

    alias_response = (
        supabase.table("souler_aliases")
        .select("souler_id")
        .eq("alias", query)
        .limit(1)
        .execute()
    )
    alias_row = _first_row(alias_response.data)
    souler_id = str(alias_row.get("souler_id", "")).strip() if alias_row else ""
    if not souler_id:
        return None

    souler_response = (
        supabase.table("soulers")
        .select("*")
        .eq("id", souler_id)
        .limit(1)
        .execute()
    )
    return _first_row(souler_response.data)


def create_souler(name: str) -> dict[str, Any]:
    cleaned_name = name.strip()
    if not cleaned_name:
        raise ValueError("Souler name cannot be empty")

    response = (
        supabase.table("soulers")
        .insert(
            {
                "name": cleaned_name,
            },
            returning="representation",
        )
        .execute()
    )

    row = _first_row(response.data)
    if not row:
        raise ValueError("Failed to create souler")
    return row


def add_souler_alias(souler_id: str, souler_name: str, alias: str) -> None:
    cleaned_alias = alias.strip()
    if not cleaned_alias:
        return

    if souler_name.strip() == cleaned_alias:
        return

    existing = get_souler_by_alias(cleaned_alias)
    if existing:
        return

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
