from __future__ import annotations

from app.db.session import fetch_one


async def is_user_premium(user_id: str) -> bool:
    row = await fetch_one(
        """
        SELECT COALESCE(
            NULLIF(trim(product_id), '') IS NOT NULL
            AND expiration_at IS NOT NULL
            AND expiration_at > NOW(),
            FALSE
        ) AS is_premium
        FROM public.billings
        WHERE user_id = %(user_id)s::uuid
        """,
        {"user_id": user_id},
    )
    return bool(row and row["is_premium"])
