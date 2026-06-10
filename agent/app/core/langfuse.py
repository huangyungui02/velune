from __future__ import annotations

import logging
from functools import lru_cache
from typing import Any

from app.core.config import get_settings

logger = logging.getLogger(__name__)


def langfuse_callbacks() -> list[Any]:
    if not _is_langfuse_configured():
        return []

    try:
        from langfuse.langchain import CallbackHandler
    except ImportError:
        logger.warning("Langfuse is enabled but the langfuse package is not installed.")
        return []

    try:
        _get_langfuse_client()
        return [CallbackHandler(public_key=get_settings().LANGFUSE_PUBLIC_KEY)]
    except Exception as exc:  # noqa: BLE001
        logger.warning("Failed to initialize Langfuse callback: %s: %s", type(exc).__name__, exc)
        return []


def langfuse_metadata(
    *,
    user_id: str | None,
    session_id: str,
    metadata: dict[str, Any] | None = None,
) -> dict[str, Any]:
    trace_metadata: dict[str, Any] = {
        "langfuse_session_id": session_id,
    }
    if user_id:
        trace_metadata["langfuse_user_id"] = user_id
    if metadata:
        trace_metadata.update(_safe_trace_metadata(metadata))
    return trace_metadata


def flush_langfuse() -> None:
    if not _is_langfuse_configured():
        return

    try:
        _get_langfuse_client().flush()
    except Exception as exc:  # noqa: BLE001
        logger.warning("Failed to flush Langfuse traces: %s: %s", type(exc).__name__, exc)


@lru_cache(maxsize=1)
def _get_langfuse_client() -> Any:
    settings = get_settings()
    from langfuse import Langfuse

    return Langfuse(
        public_key=settings.LANGFUSE_PUBLIC_KEY,
        secret_key=settings.LANGFUSE_SECRET_KEY,
        base_url=settings.LANGFUSE_BASE_URL,
        tracing_enabled=settings.LANGFUSE_ENABLED,
    )


def _is_langfuse_configured() -> bool:
    settings = get_settings()
    return (
        settings.LANGFUSE_ENABLED
        and bool(settings.LANGFUSE_PUBLIC_KEY)
        and bool(settings.LANGFUSE_SECRET_KEY)
    )


def _safe_trace_metadata(metadata: dict[str, Any]) -> dict[str, Any]:
    allowed_keys = {
        "intent",
        "lang",
        "memoryEnabled",
        "model",
        "timezone",
    }
    return {key: value for key, value in metadata.items() if key in allowed_keys}
