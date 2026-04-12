from __future__ import annotations

from typing import Any

from ._client import first_row, supabase


def start_souler_chapters_generation(souler_id: str) -> dict[str, Any]:
    response = (
        supabase.rpc(
            "start_souler_chapters_generation",
            {
                "p_souler_id": souler_id,
            },
        )
        .execute()
    )
    row = first_row(response.data)
    if not row:
        raise ValueError("Failed to start chapter generation")
    return row


def complete_souler_chapters_generation(
    souler_id: str,
    chapters: list[dict[str, str]],
) -> None:
    supabase.rpc(
        "complete_souler_chapters_generation",
        {
            "p_souler_id": souler_id,
            "p_chapters": chapters,
        },
    ).execute()


def fail_souler_chapters_generation(souler_id: str, error_message: str) -> None:
    supabase.rpc(
        "fail_souler_chapters_generation",
        {
            "p_souler_id": souler_id,
            "p_error": error_message,
        },
    ).execute()
