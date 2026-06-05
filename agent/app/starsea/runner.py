from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from typing import Any
from uuid import uuid4

from langchain_core.messages import HumanMessage

from app.core.common import Lang, validate_lang
from app.core.llm import model_for_premium
from app.starsea.checkpoint import checkpoint_manager
from app.starsea.graph import build_graph
from app.starsea.state import ArchiveEvent, State

logger = logging.getLogger(__name__)


async def stream_graph(
    user_input: str,
    metadata: dict[str, Any] | None = None,
    thread_id: str | None = None,
    intent: str | None = None,
    user_id: str | None = None,
    is_premium: bool = False,
    lang: Lang = "zh",
) -> AsyncIterator[dict[str, Any]]:
    thread_id = thread_id or str(uuid4())
    config = {"configurable": {"thread_id": thread_id}}
    graph = build_graph()

    try:
        if user_id is not None:
            snapshot = await graph.aget_state(config)
            _ensure_thread_owner(snapshot.values, user_id)

        async for chunk in graph.astream(
            _initial_state(
                user_input,
                metadata,
                intent,
                user_id=user_id,
                is_premium=is_premium,
                lang=lang,
            ),
            config,
            stream_mode="custom",
        ):
            yield _event_from_chunk(chunk, thread_id)

        snapshot = await graph.aget_state(config)
        result = snapshot.values
        if _should_delete_checkpoint(result):
            await _delete_checkpoint(thread_id)

        yield {
            "event": "completed",
            "thread_id": thread_id,
            "data": {
                "status": "completed",
                "thread_id": thread_id,
                "glimmer": result.get("glimmer"),
            },
        }
    except Exception as exc:
        logger.warning(
            "LangGraph stream failed for thread %s: %s: %s",
            thread_id,
            type(exc).__name__,
            exc,
        )
        yield {
            "event": "error",
            "thread_id": thread_id,
            "data": {
                "status": "failed",
                "thread_id": thread_id,
                "error": type(exc).__name__,
                "message": str(exc) or "LangGraph stream failed.",
            },
        }


def _initial_state(
    user_input: str,
    metadata: dict[str, Any] | None = None,
    intent: str | None = None,
    *,
    user_id: str | None = None,
    is_premium: bool = False,
    lang: Lang = "zh",
) -> State:
    normalized_lang = validate_lang(lang)
    runtime_metadata = {
        "lang": normalized_lang,
        **(metadata or {}),
    }
    runtime_metadata["lang"] = validate_lang(str(runtime_metadata.get("lang") or normalized_lang))
    if user_id is not None:
        runtime_metadata["user_id"] = user_id
    if intent is not None:
        runtime_metadata["intent"] = intent
    runtime_metadata["model"] = model_for_premium(is_premium)

    content = user_input.strip()
    messages = [HumanMessage(content=content)] if content else []
    archive_events: list[ArchiveEvent] = []
    if content:
        archive_events.append(
            {
                "type": "message",
                "role": "user",
                "content": content,
                "payload": {},
            }
        )

    initial_state: State = {
        "messages": messages,
        "archive_events": archive_events,
        "glimmer": None,
        "metadata": runtime_metadata,
    }

    return initial_state


def _event_from_chunk(chunk: Any, thread_id: str) -> dict[str, Any]:
    if isinstance(chunk, dict) and chunk.get("type") == "message_delta":
        return {
            "event": "message_delta",
            "thread_id": thread_id,
            "data": {
                "display_type": chunk.get("display_type"),
                "delta": chunk.get("delta", ""),
            },
        }
    if isinstance(chunk, dict) and chunk.get("type") == "resonance_match":
        return {
            "event": "resonance_match",
            "thread_id": thread_id,
            "data": chunk["matches"],
        }
    if isinstance(chunk, dict) and chunk.get("type") == "conversation_options":
        return {
            "event": "conversation_options",
            "thread_id": thread_id,
            "data": {
                "options": chunk.get("options", []),
            },
        }
    return {
        "event": "custom",
        "thread_id": thread_id,
        "data": chunk,
    }


def _ensure_thread_owner(values: dict[str, Any], user_id: str) -> None:
    metadata = values.get("metadata")
    if not isinstance(metadata, dict):
        return

    owner_id = str(metadata.get("user_id") or "").strip()
    if owner_id and owner_id != user_id:
        raise PermissionError("Starsea thread does not belong to the current user")


def _should_delete_checkpoint(values: dict[str, Any]) -> bool:
    metadata = values.get("metadata")
    return (
        isinstance(metadata, dict)
        and metadata.get("intent") == "collect"
        and isinstance(values.get("glimmer"), dict)
    )


async def _delete_checkpoint(thread_id: str) -> None:
    try:
        await checkpoint_manager.get().adelete_thread(thread_id)
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "Failed to delete starsea checkpoint for thread %s after glimmer archive: %s: %s",
            thread_id,
            type(exc).__name__,
            exc,
        )
