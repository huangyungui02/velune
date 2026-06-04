from __future__ import annotations

from typing import Any

from app.db.session import database_manager, execute, execute_fetch_one, fetch_one


def normalize_name_key(name: str) -> str:
    return " ".join(name.strip().lower().split())


async def find_souler_by_alias(alias: str, _lang: str | None = None) -> dict[str, Any] | None:
    return await fetch_one(
        """
        SELECT s.id, s.wiki_id
        FROM public.souler_aliases a
        INNER JOIN public.soulers s ON s.id = a.souler_id
        WHERE lower(trim(a.alias)) = %(alias_key)s
        LIMIT 1
        """,
        {"alias_key": normalize_name_key(alias)},
    )


async def find_souler_by_wiki_id(wiki_id: str) -> dict[str, Any] | None:
    return await fetch_one(
        """
        SELECT id, wiki_id
        FROM public.soulers
        WHERE wiki_id = %(wiki_id)s
        LIMIT 1
        """,
        {"wiki_id": wiki_id.strip().upper()},
    )


async def get_souler_lang_content_state(souler_id: str, lang: str) -> dict[str, Any]:
    row = await fetch_one(
        """
        SELECT
            EXISTS (
                SELECT 1
                FROM public.souler_profile p
                WHERE p.souler_id = CAST(%(souler_id)s AS uuid)
                    AND p.lang = %(lang)s
                    AND NULLIF(trim(COALESCE(p.name, '')), '') IS NOT NULL
                    AND NULLIF(trim(COALESCE(p.introduction, '')), '') IS NOT NULL
            ) AS has_profile,
            EXISTS (
                SELECT 1
                FROM public.chapters c
                WHERE c.souler_id = CAST(%(souler_id)s AS uuid)
                    AND c.lang = %(lang)s
                    AND c.active = TRUE
            ) AS has_chapters
        """,
        {"souler_id": souler_id, "lang": lang},
    )
    return row or {"has_profile": False, "has_chapters": False}


def is_souler_lang_content_complete(state: dict[str, Any]) -> bool:
    return bool(state.get("has_profile")) and bool(state.get("has_chapters"))


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


async def complete_existing_resolution_transactionally(
    request_id: str,
    *,
    souler_id: str,
    aliases: list[str | None],
    canonical_name: str | None,
    wiki_id: str | None,
) -> None:
    async with database_manager.get_pool().connection() as connection:
        async with connection.transaction():
            async with connection.cursor() as cursor:
                await _insert_souler_aliases(cursor, souler_id, aliases)
                await _complete_resolution(
                    cursor,
                    request_id=request_id,
                    souler_id=souler_id,
                    canonical_name=canonical_name,
                    wiki_id=wiki_id,
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


async def complete_souler_resolution_transactionally(
    *,
    request_id: str,
    souler_id: str | None,
    wiki_id: str | None,
    lang: str,
    profile: dict[str, Any] | None,
    aliases: list[str | None],
    canonical_name: str | None,
) -> dict[str, Any]:
    cleaned_wiki_id = wiki_id.strip().upper() if wiki_id else None
    async with database_manager.get_pool().connection() as connection:
        async with connection.transaction():
            async with connection.cursor() as cursor:
                resolved_souler_id = souler_id
                if resolved_souler_id is None:
                    souler = await _insert_souler(cursor, cleaned_wiki_id)
                    resolved_souler_id = str(souler["id"])

                state = await _get_souler_lang_content_state(cursor, resolved_souler_id, lang)
                if profile is not None and not is_souler_lang_content_complete(state):
                    await _upsert_profile(
                        cursor,
                        souler_id=resolved_souler_id,
                        lang=lang,
                        name=profile["name"],
                        introduction=profile["introduction"],
                    )
                    await _insert_keywords(
                        cursor,
                        souler_id=resolved_souler_id,
                        lang=lang,
                        keywords=profile["keywords"],
                    )
                    await _insert_chapters(
                        cursor,
                        souler_id=resolved_souler_id,
                        lang=lang,
                        chapters=profile["chapters"],
                    )

                await _insert_souler_aliases(cursor, resolved_souler_id, aliases)
                await _complete_resolution(
                    cursor,
                    request_id=request_id,
                    souler_id=resolved_souler_id,
                    canonical_name=canonical_name,
                    wiki_id=cleaned_wiki_id,
                )

                return {"id": resolved_souler_id, "wiki_id": cleaned_wiki_id}


async def _insert_souler(cursor: Any, wiki_id: str | None) -> dict[str, Any]:
    await cursor.execute(
        """
        INSERT INTO public.soulers (wiki_id, checked)
        VALUES (%(wiki_id)s, false)
        ON CONFLICT (wiki_id) WHERE wiki_id IS NOT NULL DO NOTHING
        RETURNING id, wiki_id
        """,
        {"wiki_id": wiki_id},
    )
    souler = await cursor.fetchone()
    if souler:
        return dict(souler)

    if wiki_id is None:
        raise RuntimeError("Failed to create souler")

    await cursor.execute(
        """
        SELECT id, wiki_id
        FROM public.soulers
        WHERE wiki_id = %(wiki_id)s
        LIMIT 1
        """,
        {"wiki_id": wiki_id},
    )
    souler = await cursor.fetchone()
    if not souler:
        raise RuntimeError("Failed to resolve existing souler after wiki_id conflict")
    return dict(souler)


async def _get_souler_lang_content_state(cursor: Any, souler_id: str, lang: str) -> dict[str, Any]:
    await cursor.execute(
        """
        SELECT
            EXISTS (
                SELECT 1
                FROM public.souler_profile p
                WHERE p.souler_id = CAST(%(souler_id)s AS uuid)
                    AND p.lang = %(lang)s
                    AND NULLIF(trim(COALESCE(p.name, '')), '') IS NOT NULL
                    AND NULLIF(trim(COALESCE(p.introduction, '')), '') IS NOT NULL
            ) AS has_profile,
            EXISTS (
                SELECT 1
                FROM public.chapters c
                WHERE c.souler_id = CAST(%(souler_id)s AS uuid)
                    AND c.lang = %(lang)s
                    AND c.active = TRUE
            ) AS has_chapters
        """,
        {"souler_id": souler_id, "lang": lang},
    )
    row = await cursor.fetchone()
    return dict(row) if row else {"has_profile": False, "has_chapters": False}


async def _upsert_profile(
    cursor: Any,
    *,
    souler_id: str,
    lang: str,
    name: str,
    introduction: str,
) -> None:
    await cursor.execute(
        """
        INSERT INTO public.souler_profile (souler_id, lang, name, introduction)
        VALUES (
            CAST(%(souler_id)s AS uuid),
            %(lang)s,
            %(name)s,
            %(introduction)s
        )
        ON CONFLICT (souler_id, lang) DO UPDATE SET
            name = COALESCE(NULLIF(trim(souler_profile.name), ''), EXCLUDED.name),
            introduction = COALESCE(
                NULLIF(trim(souler_profile.introduction), ''),
                EXCLUDED.introduction
            )
        """,
        {
            "souler_id": souler_id,
            "lang": lang,
            "name": name,
            "introduction": introduction,
        },
    )


async def _insert_keywords(
    cursor: Any,
    *,
    souler_id: str,
    lang: str,
    keywords: list[dict[str, Any]],
) -> None:
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
            ON CONFLICT (souler_id, keyword_id) DO UPDATE SET
                weight = EXCLUDED.weight
            """,
            {
                "souler_id": souler_id,
                "keyword_id": keyword_id,
                "weight": item["weight"],
            },
        )


async def _insert_chapters(
    cursor: Any,
    *,
    souler_id: str,
    lang: str,
    chapters: list[dict[str, str]],
) -> None:
    for index, chapter in enumerate(chapters, start=1):
        await cursor.execute(
            """
            INSERT INTO public.chapters (souler_id, lang, seq, title, subtitle, task)
            VALUES (
                CAST(%(souler_id)s AS uuid),
                %(lang)s,
                %(seq)s,
                %(title)s,
                %(subtitle)s,
                %(task)s
            )
            ON CONFLICT (souler_id, lang, seq) WHERE active = TRUE DO NOTHING
            """,
            {
                "souler_id": souler_id,
                "lang": lang,
                "seq": index,
                "title": chapter["title"],
                "subtitle": chapter["subtitle"],
                "task": chapter["task"],
            },
        )


async def _insert_souler_aliases(cursor: Any, souler_id: str, aliases: list[str | None]) -> None:
    for alias in dict.fromkeys((item or "").strip() for item in aliases):
        if not alias:
            continue
        await cursor.execute(
            """
            INSERT INTO public.souler_aliases (souler_id, alias)
            VALUES (CAST(%(souler_id)s AS uuid), %(alias)s)
            ON CONFLICT (alias) DO NOTHING
            """,
            {"souler_id": souler_id, "alias": alias},
        )


async def _complete_resolution(
    cursor: Any,
    *,
    request_id: str,
    souler_id: str,
    canonical_name: str | None,
    wiki_id: str | None,
) -> None:
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
            "wiki_id": wiki_id,
        },
    )
