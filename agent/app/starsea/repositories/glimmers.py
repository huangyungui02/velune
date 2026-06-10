from __future__ import annotations

from typing import Any, TypedDict

from psycopg.types.json import Jsonb

from app.db.session import database_manager, execute_fetch_one, fetch_all, fetch_one


class Glimmer(TypedDict):
    id: str
    user_id: str
    content: str
    keywords: list[str]
    created_at: str


class GlimmerMessage(TypedDict):
    id: str
    glimmer_id: str
    sequence: int
    type: str
    role: str | None
    content: str | None
    payload: dict[str, Any]
    created_at: str


class GlimmerMessageDraft(TypedDict):
    type: str
    role: str | None
    content: str | None
    payload: dict[str, Any]


async def get_glimmer_by_id(user_id: str, glimmer_id: str) -> Glimmer | None:
    row = await fetch_one(
        """
        SELECT id, user_id, content, keywords, created_at
        FROM public.glimmers
        WHERE id = CAST(%(glimmer_id)s AS uuid)
          AND user_id = CAST(%(user_id)s AS uuid)
        """,
        {"user_id": user_id, "glimmer_id": glimmer_id},
    )
    if not row:
        return None

    return {
        "id": str(row.get("id", "")),
        "user_id": str(row.get("user_id", "")),
        "content": str(row.get("content", "")),
        "keywords": _row_keywords(row.get("keywords")),
        "created_at": str(row.get("created_at", "")),
    }


async def get_recent_glimmers(user_id: str, limit: int = 5) -> list[Glimmer]:
    rows = await fetch_all(
        """
        SELECT id, user_id, content, keywords, created_at
        FROM public.glimmers
        WHERE user_id = CAST(%(user_id)s AS uuid)
        ORDER BY created_at DESC
        LIMIT %(limit)s
        """,
        {"user_id": user_id, "limit": max(1, min(limit, 20))},
    )

    return [
        {
            "id": str(row.get("id", "")),
            "user_id": str(row.get("user_id", "")),
            "content": str(row.get("content", "")),
            "keywords": _row_keywords(row.get("keywords")),
            "created_at": str(row.get("created_at", "")),
        }
        for row in rows
    ]


async def get_glimmer_messages(
    user_id: str,
    glimmer_id: str,
) -> list[GlimmerMessage]:
    rows = await fetch_all(
        """
        SELECT id, glimmer_id, sequence, type, role, content, payload, created_at
        FROM public.glimmer_messages
        WHERE user_id = CAST(%(user_id)s AS uuid)
          AND glimmer_id = CAST(%(glimmer_id)s AS uuid)
          AND type = 'message'
          AND role IN ('user', 'assistant')
        ORDER BY sequence ASC
        """,
        {"user_id": user_id, "glimmer_id": glimmer_id},
    )

    return [
        {
            "id": str(row.get("id", "")),
            "glimmer_id": str(row.get("glimmer_id", "")),
            "sequence": int(row.get("sequence") or 0),
            "type": str(row.get("type", "")),
            "role": _row_optional_str(row.get("role")),
            "content": _row_optional_str(row.get("content")),
            "payload": _row_payload(row.get("payload")),
            "created_at": str(row.get("created_at", "")),
        }
        for row in rows
    ]


async def create_glimmer(
    user_id: str,
    content: str,
    keywords: list[str] | None = None,
) -> Glimmer:
    row = await execute_fetch_one(
        """
        INSERT INTO public.glimmers (user_id, content, keywords)
        VALUES (CAST(%(user_id)s AS uuid), %(content)s, %(keywords)s)
        RETURNING id, user_id, content, keywords, created_at
        """,
        {"user_id": user_id, "content": content, "keywords": _clean_keywords(keywords)},
    )
    if not row:
        raise RuntimeError("Failed to create glimmer")

    return {
        "id": str(row.get("id", "")),
        "user_id": str(row.get("user_id", "")),
        "content": str(row.get("content", "")),
        "keywords": _row_keywords(row.get("keywords")),
        "created_at": str(row.get("created_at", "")),
    }


async def create_glimmer_with_messages(
    user_id: str,
    content: str,
    keywords: list[str],
    messages: list[GlimmerMessageDraft],
) -> Glimmer:
    if not messages:
        raise ValueError("Glimmer archive messages cannot be empty")

    async with database_manager.get_pool().connection() as connection:
        async with connection.transaction():
            async with connection.cursor() as cursor:
                await cursor.execute(
                    """
                    INSERT INTO public.glimmers (user_id, content, keywords)
                    VALUES (CAST(%(user_id)s AS uuid), %(content)s, %(keywords)s)
                    RETURNING id, user_id, content, keywords, created_at
                    """,
                    {
                        "user_id": user_id,
                        "content": content,
                        "keywords": _clean_keywords(keywords),
                    },
                )
                row = await cursor.fetchone()
                if not row:
                    raise RuntimeError("Failed to create glimmer")

                glimmer_id = str(row["id"])
                await cursor.executemany(
                    """
                    INSERT INTO public.glimmer_messages (
                        user_id,
                        glimmer_id,
                        sequence,
                        type,
                        role,
                        content,
                        payload
                    )
                    VALUES (
                        CAST(%(user_id)s AS uuid),
                        CAST(%(glimmer_id)s AS uuid),
                        %(sequence)s,
                        %(type)s,
                        %(role)s,
                        %(content)s,
                        %(payload)s
                    )
                    """,
                    [
                        {
                            "user_id": user_id,
                            "glimmer_id": glimmer_id,
                            "sequence": index,
                            "type": message["type"],
                            "role": message.get("role"),
                            "content": message.get("content"),
                            "payload": Jsonb(message.get("payload") or {}),
                        }
                        for index, message in enumerate(messages)
                    ],
                )

    return {
        "id": str(row.get("id", "")),
        "user_id": str(row.get("user_id", "")),
        "content": str(row.get("content", "")),
        "keywords": _row_keywords(row.get("keywords")),
        "created_at": str(row.get("created_at", "")),
    }


def _clean_keywords(keywords: list[str] | None) -> list[str]:
    cleaned: list[str] = []
    seen: set[str] = set()
    for keyword in keywords or []:
        value = str(keyword).strip()
        if not value or value in seen:
            continue
        seen.add(value)
        cleaned.append(value)
        if len(cleaned) == 3:
            break
    return cleaned


def _row_keywords(value: Any) -> list[str]:
    if not isinstance(value, list | tuple):
        return []
    return _clean_keywords([str(item) for item in value])


def _row_optional_str(value: Any) -> str | None:
    if value is None:
        return None
    return str(value)


def _row_payload(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}
