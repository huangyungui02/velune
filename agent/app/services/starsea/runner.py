from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from typing import Any
from uuid import uuid4

from langchain_core.messages import HumanMessage
from langgraph.types import Command

from app.services.starsea.graph import build_graph
from app.services.starsea.state import ArchiveEvent, State
from app.core.config import get_settings

logger = logging.getLogger(__name__)


async def run_graph(
    user_input: str,
    metadata: dict[str, Any] | None = None,
    thread_id: str | None = None,
    intent: str | None = None,
    user_id: str | None = None,
) -> dict[str, Any]:
    thread_id = thread_id or str(uuid4())
    config = {"configurable": {"thread_id": thread_id}}
    result = await build_graph().ainvoke(
        _initial_state(user_input, metadata, intent, user_id=user_id),
        config,
    )

    payload: dict[str, Any] = {
        "status": "completed",
        "thread_id": thread_id,
        "display": _display_from_result(result),
    }

    return payload


async def stream_graph(
    user_input: str,
    metadata: dict[str, Any] | None = None,
    thread_id: str | None = None,
    intent: str | None = None,
    user_id: str | None = None,
) -> AsyncIterator[dict[str, Any]]:
    thread_id = thread_id or str(uuid4())
    config = {"configurable": {"thread_id": thread_id}}
    graph = build_graph()

    try:
        async for chunk in graph.astream(
            _initial_state(user_input, metadata, intent, user_id=user_id),
            config,
            stream_mode="custom",
        ):
            yield _event_from_chunk(chunk, thread_id)

        snapshot = await graph.aget_state(config)
        interrupt_payload = _interrupt_payload(snapshot)
        if interrupt_payload is not None:
            yield {
                "event": "confirm_required",
                "thread_id": thread_id,
                "data": interrupt_payload,
            }
            return

        result = snapshot.values
        yield {
            "event": "completed",
            "thread_id": thread_id,
            "data": {
                "status": "completed",
                "thread_id": thread_id,
                "display": _display_from_result(result),
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


async def resume_graph(
    *,
    thread_id: str,
    user_id: str,
    approved: bool,
    content: str | None,
) -> AsyncIterator[dict[str, Any]]:
    config = {"configurable": {"thread_id": thread_id}}
    graph = build_graph()
    resume_payload = {
        "approved": approved,
        "content": content or "",
    }

    try:
        snapshot = await graph.aget_state(config)
        _ensure_thread_owner(snapshot.values, user_id)

        async for chunk in graph.astream(
            Command(resume=resume_payload),
            config,
            stream_mode="custom",
        ):
            yield _event_from_chunk(chunk, thread_id)

        snapshot = await graph.aget_state(config)
        interrupt_payload = _interrupt_payload(snapshot)
        if interrupt_payload is not None:
            yield {
                "event": "confirm_required",
                "thread_id": thread_id,
                "data": interrupt_payload,
            }
            return

        result = snapshot.values
        display = result.get("display")
        if isinstance(display, dict) and display.get("type") == "glimmer":
            yield {
                "event": "completed",
                "thread_id": thread_id,
                "data": {
                    "status": "completed",
                    "thread_id": thread_id,
                    "display": display,
                },
            }
            return

        yield {
            "event": "discarded",
            "thread_id": thread_id,
            "data": {
                "status": "discarded",
                "thread_id": thread_id,
            },
        }
    except Exception as exc:
        logger.warning(
            "LangGraph resume failed for thread %s: %s: %s",
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
                "message": str(exc) or "LangGraph resume failed.",
            },
        }


def _initial_state(
    user_input: str,
    metadata: dict[str, Any] | None = None,
    intent: str | None = None,
    *,
    user_id: str | None = None,
) -> State:
    settings = get_settings()
    runtime_metadata = {
        "app_env": settings.APP_ENV,
        **(metadata or {}),
    }
    if user_id is not None:
        runtime_metadata["user_id"] = user_id
    if intent is not None:
        runtime_metadata["intent"] = intent

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
        "display": None,
        "archive_events": archive_events,
        "pending_glimmer": None,
        "confirmed_glimmer": None,
        "created_glimmer_id": None,
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
    return {
        "event": "custom",
        "thread_id": thread_id,
        "data": chunk,
    }


def _interrupt_payload(snapshot: Any) -> Any | None:
    for task in getattr(snapshot, "tasks", ()) or ():
        for interrupt in getattr(task, "interrupts", ()) or ():
            return getattr(interrupt, "value", None)

    return None


def _ensure_thread_owner(values: dict[str, Any], user_id: str) -> None:
    metadata = values.get("metadata")
    if not isinstance(metadata, dict):
        raise ValueError("Starsea thread is not resumable")

    owner_id = str(metadata.get("user_id") or "").strip()
    if owner_id != user_id:
        raise PermissionError("Starsea thread does not belong to the current user")


def _display_from_result(result: dict[str, Any]) -> dict[str, Any]:
    display = result.get("display")
    if display is not None:
        return display

    msg = "graph result must include a display payload"
    raise ValueError(msg)
