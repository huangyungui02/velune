from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from typing import Any
from uuid import uuid4

from langchain_core.messages import HumanMessage

from app.services.starsea.graph import build_graph
from app.services.starsea.state import State
from app.core.config import get_settings

logger = logging.getLogger(__name__)


async def run_graph(
    user_input: str,
    metadata: dict[str, Any] | None = None,
    thread_id: str | None = None,
    intent: str | None = None,
) -> dict[str, Any]:
    thread_id = thread_id or str(uuid4())
    config = {"configurable": {"thread_id": thread_id}}
    result = await build_graph().ainvoke(_initial_state(user_input, metadata, intent), config)

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
) -> AsyncIterator[dict[str, Any]]:
    thread_id = thread_id or str(uuid4())
    config = {"configurable": {"thread_id": thread_id}}
    graph = build_graph()

    try:
        async for chunk in graph.astream(
            _initial_state(user_input, metadata, intent),
            config,
            stream_mode="custom",
        ):
            if isinstance(chunk, dict) and chunk.get("type") == "message_delta":
                yield {
                    "event": "message_delta",
                    "thread_id": thread_id,
                    "data": {
                        "display_type": chunk.get("display_type"),
                        "delta": chunk.get("delta", ""),
                    },
                }
            elif isinstance(chunk, dict) and chunk.get("type") == "resonance_match":
                yield {
                    "event": "resonance_match",
                    "thread_id": thread_id,
                    "data": chunk["matches"],
                }
            else:
                yield {
                    "event": "custom",
                    "thread_id": thread_id,
                    "data": chunk,
                }

        result = (await graph.aget_state(config)).values
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


def _initial_state(
    user_input: str,
    metadata: dict[str, Any] | None = None,
    intent: str | None = None,
) -> State:
    settings = get_settings()
    runtime_metadata = {
        "app_env": settings.APP_ENV,
        **(metadata or {}),
    }
    if intent is not None:
        runtime_metadata["intent"] = intent

    messages = [HumanMessage(content=user_input)] if user_input.strip() else []
    initial_state: State = {
        "messages": messages,
        "display": None,
        "metadata": runtime_metadata,
    }

    return initial_state


def _display_from_result(result: dict[str, Any]) -> dict[str, Any]:
    display = result.get("display")
    if display is not None:
        return display

    msg = "graph result must include a display payload"
    raise ValueError(msg)
