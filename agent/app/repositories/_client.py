from __future__ import annotations

from typing import Any

from supabase import Client, create_client

from app.config import get_settings

settings = get_settings()
supabase: Client = create_client(
    settings.SUPABASE_URL,
    settings.SUPABASE_SERVICE_ROLE_KEY,
)


def first_row(data: Any) -> dict[str, Any] | None:
    if isinstance(data, list):
        return data[0] if data else None
    if isinstance(data, dict):
        return data
    return None
