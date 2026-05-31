from __future__ import annotations

from typing import TYPE_CHECKING, Any

from app.starsea.repositories.glimmers import create_glimmer_with_messages

if TYPE_CHECKING:
    from app.starsea.state import State


async def glimmer_node(state: State) -> dict[str, Any]:
    user_id = str(state.get("metadata", {}).get("user_id") or "").strip()
    content = str(state.get("glimmer_content") or "").strip()
    archive_events = _clean_archive_events(state.get("archive_events") or [])

    if not user_id:
        raise ValueError("Missing user_id for glimmer archive")
    if not content:
        raise ValueError("Glimmer content cannot be empty")
    if not archive_events:
        raise ValueError("Glimmer archive messages cannot be empty")

    glimmer = await create_glimmer_with_messages(user_id, content, archive_events)

    return {
        "display": {
            "type": "glimmer",
            "glimmer": {
                "id": glimmer["id"],
                "content": glimmer["content"],
                "createdAt": glimmer["created_at"],
            },
        },
    }


def _clean_archive_events(events: list[Any]) -> list[dict[str, Any]]:
    cleaned: list[dict[str, Any]] = []
    for event in events:
        if not isinstance(event, dict):
            continue

        event_type = str(event.get("type") or "").strip()
        role = event.get("role")
        content = event.get("content")
        payload = event.get("payload")
        if role is not None:
            role = str(role)
        if content is not None:
            content = str(content).strip() or None
        if not isinstance(payload, dict):
            payload = {}

        if not event_type or (content is None and not payload):
            continue

        cleaned.append(
            {
                "type": event_type,
                "role": role,
                "content": content,
                "payload": payload,
            }
        )

    return cleaned
