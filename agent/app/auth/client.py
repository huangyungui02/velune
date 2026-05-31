from __future__ import annotations

from supabase import AsyncClient, acreate_client

from app.core.config import get_settings

settings = get_settings()

_supabase_auth: AsyncClient | None = None


async def init_supabase_auth() -> AsyncClient:
    global _supabase_auth
    if _supabase_auth is not None:
        return _supabase_auth

    _supabase_auth = await acreate_client(
        settings.SUPABASE_URL,
        settings.SUPABASE_SERVICE_ROLE_KEY,
    )
    return _supabase_auth


def get_supabase_auth() -> AsyncClient:
    if _supabase_auth is None:
        raise RuntimeError("Supabase auth client not initialized; app lifespan did not run")
    return _supabase_auth
