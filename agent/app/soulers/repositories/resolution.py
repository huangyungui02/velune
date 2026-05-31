from __future__ import annotations

from typing import Any

from app.db.session import database_manager, execute, execute_fetch_one, fetch_one


def normalize_name_key(name: str) -> str:
    return " ".join(name.strip().lower().split())


async def find_souler_by_alias(alias: str, lang: str) -> dict[str, Any] | None:
    return await fetch_one(
        """
        SELECT id, name, canonical_name, wiki_id
        FROM public.souler_aliases a
        INNER JOIN public.soulers s ON s.id = a.souler_id
        WHERE s.lang = %(lang)s
            AND lower(trim(a.alias)) = %(alias_key)s
        LIMIT 1
        """,
        {"alias_key": normalize_name_key(alias), "lang": lang},
    )


async def find_souler_by_canonical_name(canonical_name: str, lang: str) -> dict[str, Any] | None:
    return await find_souler_by_alias(canonical_name, lang)


async def find_souler_by_wiki_id(wiki_id: str, lang: str) -> dict[str, Any] | None:
    return await fetch_one(
        """
        SELECT id, name, canonical_name, wiki_id
        FROM public.soulers
        WHERE lang = %(lang)s
            AND wiki_id = %(wiki_id)s
        LIMIT 1
        """,
        {"wiki_id": wiki_id.strip().upper(), "lang": lang},
    )


async def add_souler_alias(souler_id: str, alias: str) -> None:
    cleaned = alias.strip()
    if not cleaned:
        return
    await execute(
        """
        INSERT INTO public.souler_aliases (souler_id, alias)
        VALUES (CAST(%(souler_id)s AS uuid), %(alias)s)
        ON CONFLICT (souler_id, alias) DO NOTHING
        """,
        {"souler_id": souler_id, "alias": cleaned},
    )


async def add_souler_aliases(souler_id: str, aliases: list[str | None]) -> None:
    for alias in dict.fromkeys((item or "").strip() for item in aliases):
        await add_souler_alias(souler_id, alias)


async def upsert_resolution_request(name: str, lang: str) -> dict[str, Any]:
    cleaned = name.strip()
    return await execute_fetch_one(
        """
        INSERT INTO public.souler_resolution_requests (requested_name, lang)
        VALUES (%(name)s, %(lang)s)
        ON CONFLICT (requested_name, lang)
        DO UPDATE SET
            status = CASE
                WHEN souler_resolution_requests.status = 'failed' THEN 'queued'
                ELSE souler_resolution_requests.status
            END,
            error = CASE
                WHEN souler_resolution_requests.status = 'failed' THEN NULL
                ELSE souler_resolution_requests.error
            END,
            task_id = CASE
                WHEN souler_resolution_requests.status = 'failed' THEN NULL
                ELSE souler_resolution_requests.task_id
            END
        RETURNING id, requested_name, lang, status, task_id, souler_id, canonical_name, wiki_id, error
        """,
        {"name": cleaned, "lang": lang},
    ) or {}


async def set_resolution_task_id(request_id: str, task_id: str) -> None:
    await execute(
        """
        UPDATE public.souler_resolution_requests
        SET task_id = %(task_id)s
        WHERE id = CAST(%(request_id)s AS uuid)
            AND status <> 'complete'
        """,
        {"request_id": request_id, "task_id": task_id},
    )


async def get_resolution_request(request_id: str) -> dict[str, Any] | None:
    return await fetch_one(
        """
        SELECT id, requested_name, lang, status, task_id, souler_id, canonical_name, wiki_id, error
        FROM public.souler_resolution_requests
        WHERE id = CAST(%(request_id)s AS uuid)
        """,
        {"request_id": request_id},
    )


async def mark_resolution_processing(request_id: str) -> dict[str, Any] | None:
    return await execute_fetch_one(
        """
        UPDATE public.souler_resolution_requests
        SET status = 'processing', error = NULL
        WHERE id = CAST(%(request_id)s AS uuid)
        RETURNING id, requested_name, lang, status, souler_id, canonical_name, wiki_id, error
        """,
        {"request_id": request_id},
    )


async def complete_resolution(
    request_id: str,
    *,
    souler_id: str,
    canonical_name: str | None,
    wiki_id: str | None,
) -> None:
    await execute(
        """
        UPDATE public.souler_resolution_requests
        SET
            status = 'complete',
            souler_id = CAST(%(souler_id)s AS uuid),
            canonical_name = %(canonical_name)s,
            wiki_id = %(wiki_id)s,
            error = NULL,
            completed_at = NOW()
        WHERE id = CAST(%(request_id)s AS uuid)
        """,
        {
            "request_id": request_id,
            "souler_id": souler_id,
            "canonical_name": canonical_name,
            "wiki_id": wiki_id,
        },
    )


async def fail_resolution(request_id: str, error: str) -> None:
    await execute(
        """
        UPDATE public.souler_resolution_requests
        SET status = 'failed', error = left(%(error)s, 2000)
        WHERE id = CAST(%(request_id)s AS uuid)
        """,
        {"request_id": request_id, "error": error},
    )


async def create_souler_with_profile(
    *,
    request_id: str,
    name: str,
    canonical_name: str | None,
    wiki_id: str | None,
    lang: str,
    bio: str,
    keywords: list[dict[str, Any]],
    chapters: list[dict[str, str]],
) -> dict[str, Any]:
    cleaned_name = name.strip()
    cleaned_wiki_id = wiki_id.strip().upper() if wiki_id else None
    async with database_manager.get_pool().connection() as connection:
        async with connection.transaction():
            async with connection.cursor() as cursor:
                await cursor.execute(
                    """
                    INSERT INTO public.soulers (name, canonical_name, wiki_id, lang, bio, checked)
                    VALUES (%(name)s, %(canonical_name)s, %(wiki_id)s, %(lang)s, %(bio)s, false)
                    ON CONFLICT (wiki_id, lang) WHERE wiki_id IS NOT NULL DO NOTHING
                    RETURNING id, name, canonical_name, wiki_id
                    """,
                    {
                        "name": cleaned_name,
                        "canonical_name": canonical_name,
                        "wiki_id": cleaned_wiki_id,
                        "lang": lang,
                        "bio": bio,
                    },
                )
                souler = await cursor.fetchone()
                if not souler:
                    if cleaned_wiki_id is None:
                        raise RuntimeError("Failed to create souler")
                    await cursor.execute(
                        """
                        SELECT id, name, canonical_name, wiki_id
                        FROM public.soulers
                        WHERE wiki_id = %(wiki_id)s
                            AND lang = %(lang)s
                        LIMIT 1
                        """,
                        {"wiki_id": cleaned_wiki_id, "lang": lang},
                    )
                    souler = await cursor.fetchone()
                    if not souler:
                        raise RuntimeError("Failed to resolve existing souler after wiki_id conflict")

                    souler_id = str(souler["id"])
                    await _insert_souler_aliases(cursor, souler_id, [cleaned_name, canonical_name])
                    await cursor.execute(
                        """
                        UPDATE public.souler_resolution_requests
                        SET
                            status = 'complete',
                            souler_id = CAST(%(souler_id)s AS uuid),
                            canonical_name = %(canonical_name)s,
                            wiki_id = %(wiki_id)s,
                            error = NULL,
                            completed_at = NOW()
                        WHERE id = CAST(%(request_id)s AS uuid)
                        """,
                        {
                            "request_id": request_id,
                            "souler_id": souler_id,
                            "canonical_name": canonical_name,
                            "wiki_id": cleaned_wiki_id,
                        },
                    )
                    return {
                        "id": souler_id,
                        "name": souler["name"],
                        "canonical_name": souler["canonical_name"],
                        "wiki_id": souler["wiki_id"],
                    }

                souler_id = str(souler["id"])
                await _insert_souler_aliases(cursor, souler_id, [cleaned_name, canonical_name])

                keyword_ids: dict[str, str] = {}
                for item in keywords:
                    await cursor.execute(
                        """
                        INSERT INTO public.keywords (word, language)
                        VALUES (%(word)s, %(lang)s)
                        ON CONFLICT (word, language)
                        DO UPDATE SET word = EXCLUDED.word
                        RETURNING id, word
                        """,
                        {"word": item["word"], "lang": lang},
                    )
                    keyword = await cursor.fetchone()
                    if not keyword:
                        raise RuntimeError(f"Failed to upsert keyword: {item['word']}")
                    keyword_ids[str(keyword["word"]).strip().lower()] = str(keyword["id"])

                for item in keywords:
                    keyword_id = keyword_ids.get(str(item["word"]).strip().lower())
                    if not keyword_id:
                        raise RuntimeError(f"Missing keyword id for word: {item['word']}")
                    await cursor.execute(
                        """
                        INSERT INTO public.souler_keyword (souler_id, keyword_id, weight)
                        VALUES (
                            CAST(%(souler_id)s AS uuid),
                            CAST(%(keyword_id)s AS uuid),
                            %(weight)s
                        )
                        """,
                        {
                            "souler_id": souler_id,
                            "keyword_id": keyword_id,
                            "weight": item["weight"],
                        },
                    )

                for index, chapter in enumerate(chapters, start=1):
                    await cursor.execute(
                        """
                        INSERT INTO public.chapters (souler_id, seq, title, subtitle, task)
                        VALUES (
                            CAST(%(souler_id)s AS uuid),
                            %(seq)s,
                            %(title)s,
                            %(subtitle)s,
                            %(task)s
                        )
                        """,
                        {
                            "souler_id": souler_id,
                            "seq": index,
                            "title": chapter["title"],
                            "subtitle": chapter["subtitle"],
                            "task": chapter["task"],
                        },
                    )

                await cursor.execute(
                    """
                    INSERT INTO public.souler_status (
                        souler_id,
                        bio_status,
                        bio_error,
                        chapters_status,
                        chapters_error
                    )
                    VALUES (CAST(%(souler_id)s AS uuid), 'complete', NULL, 'complete', NULL)
                    ON CONFLICT (souler_id)
                    DO UPDATE SET
                        bio_status = EXCLUDED.bio_status,
                        bio_error = EXCLUDED.bio_error,
                        chapters_status = EXCLUDED.chapters_status,
                        chapters_error = EXCLUDED.chapters_error
                    """,
                    {"souler_id": souler_id},
                )

                await cursor.execute(
                    """
                    UPDATE public.souler_resolution_requests
                    SET
                        status = 'complete',
                        souler_id = CAST(%(souler_id)s AS uuid),
                        canonical_name = %(canonical_name)s,
                        wiki_id = %(wiki_id)s,
                        error = NULL,
                        completed_at = NOW()
                    WHERE id = CAST(%(request_id)s AS uuid)
                    """,
                    {
                        "request_id": request_id,
                        "souler_id": souler_id,
                        "canonical_name": canonical_name,
                        "wiki_id": cleaned_wiki_id,
                    },
                )

                return {
                    "id": souler_id,
                    "name": souler["name"],
                    "canonical_name": souler["canonical_name"],
                    "wiki_id": souler["wiki_id"],
                }


async def _insert_souler_aliases(cursor: Any, souler_id: str, aliases: list[str | None]) -> None:
    for alias in dict.fromkeys((item or "").strip() for item in aliases):
        if not alias:
            continue
        await cursor.execute(
            """
            INSERT INTO public.souler_aliases (souler_id, alias)
            VALUES (CAST(%(souler_id)s AS uuid), %(alias)s)
            ON CONFLICT (souler_id, alias) DO NOTHING
            """,
            {"souler_id": souler_id, "alias": alias},
        )
