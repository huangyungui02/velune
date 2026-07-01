from __future__ import annotations

from typing import TYPE_CHECKING

from app.starsea.repositories.glimmers import create_glimmer_with_messages

if TYPE_CHECKING:
    from app.starsea.state import State


async def glimmer_node(state: State) -> dict[str, Any]:
    user_id = state["metadata"]["user_id"]
    glimmer = state.get("glimmer") or {}
    content = str(glimmer.get("content") or "").strip()
    keywords = glimmer.get("keywords") or []
    blessing = str(glimmer.get("blessing") or "").strip()
    archives = state["archives"]

    if not content:
        raise ValueError("Glimmer content cannot be empty")
    if not archives:
        raise ValueError("Glimmer archive messages cannot be empty")

    await create_glimmer_with_messages(user_id, content, keywords, archives)

    return {
        "glimmer": {
            "content": content,
            "keywords": keywords,
            "blessing": blessing,
        },
    }
