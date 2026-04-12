from __future__ import annotations

import asyncio
import logging
from typing import Any

from app.config import get_settings
from app.echo_logic import Lang
from app.errors import error_log_payload
from app.llm import complete_json
from app.supabase_repo import (
    complete_souler_chapters_generation,
    get_souler_by_id,
    mark_chapters_generation_failed,
    start_souler_chapters_generation,
)

from .prompt import build_generation_messages

logger = logging.getLogger(__name__)
settings = get_settings()

CHAPTER_MODEL = "qwen3.5-plus"
CHAPTER_COUNT = 10

_generation_tasks: dict[str, asyncio.Task[None]] = {}
_generation_tasks_lock = asyncio.Lock()

CHAPTER_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "chapters": {
            "type": "array",
            "minItems": CHAPTER_COUNT,
            "maxItems": CHAPTER_COUNT,
            "items": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "subtitle": {"type": "string"},
                    "role": {"type": "string"},
                    "task": {"type": "string"},
                },
                "required": ["title", "subtitle", "role", "task"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["chapters"],
    "additionalProperties": False,
}


def normalize_chapter_item(raw: Any) -> dict[str, str]:
    if not isinstance(raw, dict):
        raise ValueError("Invalid chapter format")

    title = str(raw.get("title", "")).strip()
    subtitle = str(raw.get("subtitle", "")).strip()
    role = str(raw.get("role", "")).strip()
    task = str(raw.get("task", "")).strip()
    if not title or not subtitle or not role or not task:
        raise ValueError("Chapter fields cannot be empty")

    return {
        "title": title,
        "subtitle": subtitle,
        "role": role,
        "task": task,
    }


async def generate_chapters(souler_id: str, lang: Lang) -> list[dict[str, str]]:
    souler = await asyncio.to_thread(get_souler_by_id, souler_id)
    raw = await complete_json(
        build_generation_messages(
            souler_name=souler["name"],
            lang=lang,
        ),
        model=CHAPTER_MODEL,
        schema_name="souler_chapters",
        schema=CHAPTER_SCHEMA,
        temperature=settings.MODEL_M_TEMPERATURE,
    )

    chapters_raw = raw.get("chapters") if isinstance(raw, dict) else None
    if not isinstance(chapters_raw, list) or len(chapters_raw) != CHAPTER_COUNT:
        raise ValueError("Model returned invalid chapters payload")

    return [normalize_chapter_item(item) for item in chapters_raw]


async def run_generation_job(souler_id: str, lang: Lang) -> None:
    try:
        chapters = await generate_chapters(souler_id, lang)
        await asyncio.to_thread(
            complete_souler_chapters_generation,
            souler_id,
            chapters,
        )
    except Exception as error:  # noqa: BLE001
        logger.error(
            "Failed to generate chapters for souler=%s error=%s",
            souler_id,
            error_log_payload(error),
        )
        try:
            await asyncio.to_thread(
                mark_chapters_generation_failed,
                souler_id,
            )
        except Exception as fail_error:  # noqa: BLE001
            logger.error(
                "Failed to update chapter failure state: souler=%s error=%s",
                souler_id,
                error_log_payload(fail_error),
            )
    finally:
        async with _generation_tasks_lock:
            _generation_tasks.pop(souler_id, None)


async def start_generation(souler_id: str, lang: Lang) -> tuple[int, dict[str, str]]:
    start_result = await asyncio.to_thread(start_souler_chapters_generation, souler_id)

    can_start = bool(start_result.get("can_start"))
    status = str(start_result.get("status", "")).strip() or "pending"
    message = str(start_result.get("message", "")).strip()

    if not can_start:
        return 200, {
            "status": status,
            "message": message,
        }

    async with _generation_tasks_lock:
        task = _generation_tasks.get(souler_id)
        if task and not task.done():
            return 202, {
                "status": "processing",
                "message": "chapter generation is already running",
            }

        _generation_tasks[souler_id] = asyncio.create_task(run_generation_job(souler_id, lang))

    return 202, {
        "status": "processing",
        "message": message or "chapter generation started",
    }
