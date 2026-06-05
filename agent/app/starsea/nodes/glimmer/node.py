from __future__ import annotations

from typing import TYPE_CHECKING, Any

from app.starsea.repositories.glimmers import create_glimmer_with_messages

if TYPE_CHECKING:
    from app.starsea.state import State


async def glimmer_node(state: State) -> dict[str, Any]:
    user_id = str(state.get("metadata", {}).get("user_id") or "").strip()
    glimmer = state.get("glimmer") or {}
    content = str(glimmer.get("content") or "").strip()
    keywords = _clean_keywords(glimmer.get("keywords") or [])
    blessing = str(glimmer.get("blessing") or "").strip()
    archive_events = _clean_archive_events(state.get("archive_events") or [])

    if not user_id:
        raise ValueError("Missing user_id for glimmer archive")
    if not content:
        raise ValueError("Glimmer content cannot be empty")
    if not archive_events:
        raise ValueError("Glimmer archive messages cannot be empty")

    await create_glimmer_with_messages(user_id, content, keywords, archive_events)

    return {
        "glimmer": {
            "content": content,
            "keywords": keywords,
            "blessing": blessing,
        },
    }


def _clean_keywords(value: list[Any]) -> list[str]:
    keywords: list[str] = []
    seen: set[str] = set()
    for item in value:
        keyword = str(item).strip()
        if not keyword or keyword in seen:
            continue
        seen.add(keyword)
        keywords.append(keyword)
        if len(keywords) == 3:
            break
    return keywords


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
