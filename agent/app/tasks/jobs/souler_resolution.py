from __future__ import annotations

import logging

from app.db.session import database_manager
from app.soulers.repositories.resolution import (
    add_souler_alias,
    complete_resolution,
    create_souler_with_profile,
    fail_resolution,
    find_souler_by_canonical_name,
    find_souler_by_wiki_id,
    mark_resolution_processing,
)
from app.soulers.services.profile_generation import canonicalize_souler_name, generate_profile_content
from app.soulers.services.wikipedia import search_wiki_id
from app.tasks.broker import broker

logger = logging.getLogger(__name__)


@broker.task
async def resolve_souler_request(request_id: str) -> dict[str, str]:
    await _ensure_database()
    request = await mark_resolution_processing(request_id)
    if request is None:
        return {"status": "missing", "requestId": request_id}

    name = str(request["requested_name"]).strip()
    lang = _normalize_lang(str(request["lang"]))
    try:
        canonical_name = await canonicalize_souler_name(name, lang)
        by_canonical = await find_souler_by_canonical_name(canonical_name, lang)
        if by_canonical is not None:
            souler_id = str(by_canonical["id"])
            await add_souler_alias(souler_id, name)
            await complete_resolution(
                request_id,
                souler_id=souler_id,
                canonical_name=canonical_name,
                wiki_id=by_canonical.get("wiki_id"),
            )
            return {"status": "complete", "soulerId": souler_id}

        wiki_id = await search_wiki_id(canonical_name, lang)
        if wiki_id:
            by_wiki = await find_souler_by_wiki_id(wiki_id, lang)
            if by_wiki is not None:
                souler_id = str(by_wiki["id"])
                await add_souler_alias(souler_id, name)
                await complete_resolution(
                    request_id,
                    souler_id=souler_id,
                    canonical_name=canonical_name,
                    wiki_id=wiki_id,
                )
                return {"status": "complete", "soulerId": souler_id}

        profile = await generate_profile_content(
            canonical_name=canonical_name,
            fallback_name=name,
            lang=lang,
        )
        souler = await create_souler_with_profile(
            request_id=request_id,
            name=name,
            canonical_name=canonical_name,
            wiki_id=wiki_id,
            lang=lang,
            bio=profile["bio"],
            keywords=profile["keywords"],
            chapters=profile["chapters"],
        )
        return {"status": "complete", "soulerId": str(souler["id"])}
    except Exception as error:  # noqa: BLE001
        detail = str(error) or type(error).__name__
        logger.exception("Failed to resolve souler request %s", request_id)
        await fail_resolution(request_id, detail)
        return {"status": "failed", "requestId": request_id}


async def _ensure_database() -> None:
    try:
        database_manager.get_pool()
    except RuntimeError:
        await database_manager.open()


def _normalize_lang(lang: str) -> str:
    return "zh" if lang.strip().lower().startswith("zh") else "en"
