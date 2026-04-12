from __future__ import annotations

from typing import Any

from ._client import first_row, supabase
from .types import EchoContext


def get_echo_context(user_id: str, echo_id: str) -> EchoContext:
    response = (
        supabase.table("echoes")
        .select("id, souler_id, session_id, content, glimmers!inner(user_id, content)")
        .eq("id", echo_id)
        .eq("glimmers.user_id", user_id)
        .single()
        .execute()
    )
    row = first_row(response.data)
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
    row = first_row(response.data)
    updated_session_id = str(row.get("session_id")) if row and row.get("session_id") else None
    if updated_session_id:
        return updated_session_id

    refreshed = get_echo_context(user_id, echo_id)
    if refreshed.get("session_id"):
        return str(refreshed["session_id"])

    raise ValueError("Failed to bind echo session")


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

    row = first_row(response.data)
    if not row:
        raise ValueError("Failed to create echo")
    return row
