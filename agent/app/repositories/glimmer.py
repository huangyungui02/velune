from __future__ import annotations

from typing import Any, Literal

from ._client import first_row, supabase


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
    return first_row(response.data)


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
