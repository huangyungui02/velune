from __future__ import annotations

from app.db.session import fetch_one


async def get_user_timezone(user_id: str) -> str | None:
    row = await fetch_one(
        """
        SELECT timezone
        FROM public.user_status
        WHERE user_id = CAST(%(user_id)s AS uuid)
        """,
        {"user_id": user_id},
    )
    if not row:
        return None

    timezone = str(row.get("timezone") or "").strip()
    return timezone or None
