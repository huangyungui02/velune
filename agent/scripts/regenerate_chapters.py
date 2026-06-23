from __future__ import annotations

import argparse
import asyncio
import logging
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.db.session import database_manager, fetch_all, fetch_one
from app.soulers.services.ai.chapters import SoulerChapter, generate_chapters_content

logger = logging.getLogger(__name__)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Regenerate active chapters for all soulers in one language.",
    )
    parser.add_argument("--lang", choices=("zh", "en"), required=True)
    parser.add_argument("--version", type=positive_int, required=True)
    parser.add_argument("--concurrency", type=positive_int, default=10)
    parser.add_argument("--limit", type=positive_int)
    parser.add_argument("--souler-id", action="append", default=[])
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--stop-on-error", action="store_true")
    return parser.parse_args()


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than 0")
    return parsed


async def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    args = parse_args()

    await database_manager.open()
    try:
        soulers = await load_soulers(
            lang=args.lang,
            souler_ids=args.souler_id,
            limit=args.limit,
        )
        logger.info(
            "Regenerating chapters: lang=%s version=%s count=%s concurrency=%s dry_run=%s",
            args.lang,
            args.version,
            len(soulers),
            args.concurrency,
            args.dry_run,
        )

        failures: list[tuple[dict[str, Any], str]] = []
        if args.stop_on_error:
            for index, souler in enumerate(soulers, start=1):
                failure = await process_souler(index, len(soulers), souler, args)
                if failure is not None:
                    failures.append(failure)
                    break
        else:
            semaphore = asyncio.Semaphore(args.concurrency)

            async def run_one(index: int, souler: dict[str, Any]) -> tuple[dict[str, Any], str] | None:
                async with semaphore:
                    return await process_souler(index, len(soulers), souler, args)

            results = await asyncio.gather(
                *(run_one(index, souler) for index, souler in enumerate(soulers, start=1)),
            )
            failures.extend(result for result in results if result is not None)

        if failures:
            logger.error("Completed with %s failure(s)", len(failures))
            for souler, message in failures:
                logger.error("- %s (%s): %s", souler["name"], souler["id"], message)
            return 1

        logger.info("Completed successfully")
        return 0
    finally:
        await database_manager.close()


async def load_soulers(
    *,
    lang: str,
    souler_ids: list[str],
    limit: int | None,
) -> list[dict[str, Any]]:
    rows = await fetch_all(
        """
        SELECT s.id, p.name
        FROM public.soulers AS s
        INNER JOIN public.souler_profile AS p
            ON p.souler_id = s.id
            AND p.lang = %(lang)s
        WHERE (
            %(souler_ids)s::uuid[] IS NULL
            OR s.id = ANY(%(souler_ids)s::uuid[])
        )
        ORDER BY lower(p.name), s.id
        """,
        {
            "lang": lang,
            "souler_ids": souler_ids or None,
        },
    )
    return rows[:limit] if limit is not None else rows


async def process_souler(
    index: int,
    total: int,
    souler: dict[str, Any],
    args: argparse.Namespace,
) -> tuple[dict[str, Any], str] | None:
    souler_id = str(souler["id"])
    name = str(souler["name"])
    logger.info("[%s/%s] Checking chapters for %s (%s)", index, total, name, souler_id)
    try:
        if await has_chapters_version(souler_id=souler_id, lang=args.lang, version=args.version):
            logger.info(
                "Skipped %s (%s): chapters already exist for lang=%s version=%s",
                name,
                souler_id,
                args.lang,
                args.version,
            )
            return None

        logger.info("[%s/%s] Generating chapters for %s (%s)", index, total, name, souler_id)
        chapters = await generate_chapters_content(souler_name=name, lang=args.lang)
        if args.dry_run:
            logger.info(
                "Dry run: generated %s chapters for %s; database unchanged",
                len(chapters),
                name,
            )
            return None

        inserted = await replace_active_chapters(
            souler_id=souler_id,
            lang=args.lang,
            version=args.version,
            chapters=chapters,
        )
        if inserted == 0:
            logger.info(
                "Skipped %s (%s): chapters already exist for lang=%s version=%s",
                name,
                souler_id,
                args.lang,
                args.version,
            )
            return None

        logger.info("Inserted %s active chapters for %s at version %s", inserted, name, args.version)
        return None
    except Exception as error:  # noqa: BLE001
        message = str(error) or type(error).__name__
        logger.exception("Failed to regenerate chapters for %s (%s)", name, souler_id)
        return souler, message


async def has_chapters_version(*, souler_id: str, lang: str, version: int) -> bool:
    row = await fetch_one(
        """
        SELECT EXISTS (
            SELECT 1
            FROM public.chapters
            WHERE souler_id = CAST(%(souler_id)s AS uuid)
                AND lang = %(lang)s
                AND version = %(version)s
        ) AS exists
        """,
        {"souler_id": souler_id, "lang": lang, "version": version},
    )
    return bool(row and row.get("exists"))


async def replace_active_chapters(
    *,
    souler_id: str,
    lang: str,
    version: int,
    chapters: list[SoulerChapter],
) -> int:
    async with database_manager.get_pool().connection() as connection:
        async with connection.transaction():
            async with connection.cursor() as cursor:
                await cursor.execute(
                    """
                    SELECT pg_advisory_xact_lock(hashtext(%(souler_id)s), hashtext(%(lang)s))
                    """,
                    {"souler_id": souler_id, "lang": lang},
                )
                await cursor.execute(
                    """
                    SELECT EXISTS (
                        SELECT 1
                        FROM public.chapters
                        WHERE souler_id = CAST(%(souler_id)s AS uuid)
                            AND lang = %(lang)s
                            AND version = %(version)s
                    ) AS exists
                    """,
                    {"souler_id": souler_id, "lang": lang, "version": version},
                )
                existing = await cursor.fetchone()
                if existing and existing["exists"]:
                    return 0

                await cursor.execute(
                    """
                    UPDATE public.chapters
                    SET active = FALSE
                    WHERE souler_id = CAST(%(souler_id)s AS uuid)
                        AND lang = %(lang)s
                        AND active = TRUE
                    """,
                    {"souler_id": souler_id, "lang": lang},
                )
                for index, chapter in enumerate(chapters, start=1):
                    await cursor.execute(
                        """
                        INSERT INTO public.chapters (
                            souler_id,
                            lang,
                            version,
                            seq,
                            title,
                            subtitle,
                            task
                        )
                        VALUES (
                            CAST(%(souler_id)s AS uuid),
                            %(lang)s,
                            %(version)s,
                            %(seq)s,
                            %(title)s,
                            %(subtitle)s,
                            %(task)s
                        )
                        """,
                        {
                            "souler_id": souler_id,
                            "lang": lang,
                            "version": version,
                            "seq": index,
                            "title": chapter.title,
                            "subtitle": chapter.subtitle,
                            "task": chapter.task,
                        },
                    )
    return len(chapters)


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
