from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from typing import Any

from langchain_core.messages import HumanMessage

from app.core.errors import error_message
from app.core.langfuse import langfuse_callbacks, langfuse_metadata
from app.core.llm import model_for_premium
from app.starsea.checkpoint import checkpoint_manager
from app.starsea.graph import build_graph
from app.starsea.schemas.archive import (
    DivinationArchive,
    DivinationArchiveContent,
    TextArchive,
)
from app.starsea.schemas.events import DoneEvent, ErrorEvent, SettledEvent, StarseaEvent
from app.starsea.schemas.model import DoneContent, ErrorContent, SettledContent
from app.starsea.schemas.starsea import DivinationEnvelope, StarseaContent, TextContent
from app.starsea.state import State

logger = logging.getLogger(__name__)


async def stream_graph(
    user_input: StarseaContent,
    *,
    lang: str,
    metadata: dict[str, Any],
    thread_id: str,
    user_id: str,
    is_premium: bool = False,
) -> AsyncIterator[StarseaEvent]:
    initial_state = _initial_state(
        user_input,
        metadata=metadata,
        user_id=user_id,
        is_premium=is_premium,
        lang=lang,
    )
    config = _graph_config(
        thread_id=thread_id,
        user_id=user_id,
        metadata=initial_state["metadata"],
    )
    graph = build_graph()

    try:
        snapshot = await graph.aget_state(config)
        _ensure_thread_owner(snapshot.values, user_id)

        async for chunk in graph.astream(
            initial_state,
            config,
            stream_mode="custom",
        ):
            yield chunk

        snapshot = await graph.aget_state(config)
        result = snapshot.values
        if _should_delete_checkpoint(result):
            await _delete_checkpoint(thread_id)

        glimmer = result.get("glimmer")
        if isinstance(glimmer, dict):
            yield SettledEvent(
                content=SettledContent(thread_id=thread_id, glimmer=glimmer)
            )
        else:
            yield DoneEvent(content=DoneContent(thread_id=thread_id))
    except Exception as exc:
        logger.warning(
            "LangGraph stream failed for thread %s: %s: %s",
            thread_id,
            type(exc).__name__,
            exc,
        )
        yield ErrorEvent(content=ErrorContent(message=error_message(exc)))


def _initial_state(
    user_input: StarseaContent,
    metadata: dict[str, Any],
    *,
    user_id: str,
    is_premium: bool = False,
    lang: str,
) -> State:
    runtime_metadata = {
        **metadata,
        "lang": lang,
        "user_id": user_id,
        "model": model_for_premium(is_premium),
    }

    messages: list[HumanMessage] = []
    archives: list[dict[str, Any]] = []

    if isinstance(user_input, TextContent):
        messages = [HumanMessage(content=user_input.content)]
        archives = [
            TextArchive(role="user", content=user_input.content).model_dump(mode="json")
        ]
    elif isinstance(user_input, DivinationEnvelope):
        divination = user_input.content
        archives = [
            DivinationArchive(
                content=DivinationArchiveContent(
                    casted_lines=divination.casted_lines,
                    date=divination.date.isoformat(),
                )
            ).model_dump(mode="json"),
            TextArchive(role="user", content=divination.question).model_dump(mode="json"),
        ]

    initial_state: State = {
        "user_input": user_input.model_dump(mode="json"),
        "messages": messages,
        "archives": archives,
        "glimmer": None,
        "metadata": runtime_metadata,
    }

    return initial_state


def _graph_config(
    *,
    thread_id: str,
    user_id: str,
    metadata: dict[str, Any],
) -> dict[str, Any]:
    return {
        "configurable": {"thread_id": thread_id},
        "metadata": langfuse_metadata(
            user_id=user_id,
            session_id=thread_id,
            metadata=metadata,
        ),
        "callbacks": langfuse_callbacks(),
    }


def _ensure_thread_owner(values: dict[str, Any], user_id: str) -> None:
    metadata = values.get("metadata")
    if not metadata:
        return

    if metadata["user_id"] != user_id:
        raise PermissionError("Starsea thread does not belong to the current user")


def _should_delete_checkpoint(values: dict[str, Any]) -> bool:
    user_input = values.get("user_input")
    return (
        isinstance(user_input, dict)
        and user_input.get("type") == "trigger"
        and user_input.get("content") == "collect"
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
