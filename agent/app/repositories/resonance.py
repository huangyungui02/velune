from __future__ import annotations

from .database import execute


async def create_or_update_resonance(
    user_id: str,
    souler_id: str,
    last_session_id: str | None,
    *,
    timeout: float | None = None,
) -> None:
    await execute(
        """
        INSERT INTO public.resonances (user_id, souler_id, last_session_id)
        VALUES (
            CAST(%(user_id)s AS uuid),
            CAST(%(souler_id)s AS uuid),
            CAST(%(last_session_id)s AS uuid)
        )
        ON CONFLICT (user_id, souler_id)
        DO UPDATE SET
            last_session_id = COALESCE(EXCLUDED.last_session_id, resonances.last_session_id)
        """,
        {
            "user_id": user_id,
            "souler_id": souler_id,
            "last_session_id": last_session_id,
        },
        timeout=timeout,
    )
