from __future__ import annotations

from typing import Any

from app.soulers.repositories.resolution import (
    find_souler_by_alias,
    get_resolution_request,
    set_resolution_task_id,
    upsert_resolution_request,
)
from app.tasks.jobs.souler_resolution import resolve_souler_request


def normalize_resolution_lang(lang: str | None = None) -> str:
    raw = (lang or "zh").strip().lower()
    return "zh" if raw in {"zh", "zh-hans", "zh_cn", "zh-cn"} else "en"


async def resolve_or_enqueue_souler(name: str, lang: str | None = None) -> dict[str, Any]:
    cleaned = name.strip()
    if not cleaned:
        return {"status": "failed", "error": "name is empty"}

    normalized_lang = normalize_resolution_lang(lang)
    existing = await find_souler_by_alias(cleaned, normalized_lang)
    if existing is not None:
        return {
            "status": "existing",
            "soulerId": existing["id"],
            "name": cleaned,
        }

    request = await upsert_resolution_request(cleaned, normalized_lang)
    souler_id = request.get("souler_id")
    if request.get("status") == "complete" and souler_id:
        return {
            "status": "complete",
            "soulerId": souler_id,
            "requestId": request["id"],
            "name": request.get("requested_name") or cleaned,
        }

    if request.get("task_id") and request.get("status") in {"queued", "processing"}:
        return {
            "status": "pending",
            "requestId": request["id"],
            "name": request.get("requested_name") or cleaned,
        }

    task = await resolve_souler_request.kiq(str(request["id"]))
    await set_resolution_task_id(str(request["id"]), task.task_id)
    return {
        "status": "pending",
        "requestId": request["id"],
        "name": request.get("requested_name") or cleaned,
    }


async def get_resolution_status(request_id: str) -> dict[str, Any] | None:
    row = await get_resolution_request(request_id)
    if row is None:
        return None
    payload: dict[str, Any] = {
        "status": row["status"],
        "requestId": row["id"],
        "name": row["requested_name"],
    }
    if row.get("souler_id"):
        payload["soulerId"] = row["souler_id"]
    if row.get("error"):
        payload["error"] = row["error"]
    return payload
