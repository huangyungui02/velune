from __future__ import annotations

from app.auth.client import supabase_auth_manager
from app.core.errors import UnauthorizedError
from app.db.session import await_repo


async def get_user_id_from_auth_header(authorization: str | None) -> str:
    if not authorization:
        raise UnauthorizedError("Unauthorized")

    pieces = authorization.split(" ", 1)
    if len(pieces) != 2:
        raise UnauthorizedError("Unauthorized")

    jwt = pieces[1].strip()
    if not jwt:
        raise UnauthorizedError("Unauthorized")

    user_response = await await_repo(supabase_auth_manager.get().auth.get_user(jwt))
    user = getattr(user_response, "user", None)
    user_id = getattr(user, "id", None)
    if not user_id:
        raise UnauthorizedError("Unauthorized")

    return str(user_id)
