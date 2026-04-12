from __future__ import annotations

from typing import Any

from ._client import first_row, supabase


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
    return first_row(response.data)


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
    alias_row = first_row(alias_response.data)
    if not alias_row:
        return None

    return first_row(alias_row.get("soulers"))


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

    row = first_row(response.data)
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

    row = first_row(response.data)
    if not row:
        raise ValueError("Failed to update souler")
    return row


def mark_chapters_generation_failed(souler_id: str) -> None:
    (
        supabase.table("soulers")
        .update({"chapters_status": "failed"})
        .eq("id", souler_id)
        .eq("chapters_status", "processing")
        .execute()
    )
