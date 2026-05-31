from __future__ import annotations

from supabase import AsyncClient, acreate_client

from app.core.config import get_settings


class SupabaseAuthManager:
    def __init__(self) -> None:
        self._client: AsyncClient | None = None

    async def startup(self) -> AsyncClient:
        if self._client is None:
            settings = get_settings()
            self._client = await acreate_client(
                settings.SUPABASE_URL,
                settings.SUPABASE_SERVICE_ROLE_KEY,
            )
        return self._client

    def get(self) -> AsyncClient:
        if self._client is None:
            raise RuntimeError("Supabase auth client not initialized; app lifespan did not run")
        return self._client

    def reset(self) -> None:
        self._client = None


supabase_auth_manager = SupabaseAuthManager()
