from __future__ import annotations

import logging

from app.db.session import database_manager
from app.soulers.repositories.resolution import (
    complete_existing_resolution_transactionally,
    create_souler_with_profiles_transactionally,
    fail_resolution,
    find_souler_by_alias,
    find_souler_by_wiki_id,
    mark_resolution_processing,
)
from app.soulers.services.profile_generation import canonicalize_souler_name, generate_profile_content
from app.soulers.services.wikipedia import get_wikipedia_title_by_wiki_id, search_wiki_id
from app.tasks.broker import broker

logger = logging.getLogger(__name__)
SUPPORTED_LANGS = ["zh", "en"]


@broker.task
async def resolve_souler_request(request_id: str) -> dict[str, str]:
    await _ensure_database()
    request = await mark_resolution_processing(request_id)
    if request is None:
        return {"status": "missing", "requestId": request_id}

    name = str(request["requested_name"]).strip()
    lang = _normalize_lang(str(request["lang"]))
    try:
        by_name = await find_souler_by_alias(name)
        if by_name is not None:
            souler_id = str(by_name["id"])
            await complete_existing_resolution_transactionally(
                request_id,
                souler_id=souler_id,
                aliases=[name],
                canonical_name=None,
                wiki_id=by_name.get("wiki_id"),
            )
            return {"status": "complete", "soulerId": souler_id}

        canonical_name = await canonicalize_souler_name(name, lang)
        by_canonical = await find_souler_by_alias(canonical_name)
        if by_canonical is not None:
            souler_id = str(by_canonical["id"])
            await complete_existing_resolution_transactionally(
                request_id,
                souler_id=souler_id,
                aliases=[name, canonical_name],
                canonical_name=canonical_name,
                wiki_id=by_canonical.get("wiki_id"),
            )
            return {"status": "complete", "soulerId": souler_id}

        wiki_id = await search_wiki_id(canonical_name, lang)
        if wiki_id:
            by_wiki = await find_souler_by_wiki_id(wiki_id)
            if by_wiki is not None:
                souler_id = str(by_wiki["id"])
                await complete_existing_resolution_transactionally(
                    request_id,
                    souler_id=souler_id,
                    aliases=[name, canonical_name],
                    canonical_name=canonical_name,
                    wiki_id=wiki_id,
                )
                return {"status": "complete", "soulerId": souler_id}

        profiles = []
        aliases: list[str | None] = [name, canonical_name]
        for profile_lang in SUPPORTED_LANGS:
            profile_name = canonical_name if profile_lang == lang else None
            if wiki_id:
                profile_name = profile_name or await get_wikipedia_title_by_wiki_id(
                    wiki_id,
                    profile_lang,
                )
            profile_name = (profile_name or canonical_name or name).strip()
            aliases.append(profile_name)

            profile = await generate_profile_content(
                canonical_name=profile_name,
                fallback_name=profile_name,
                lang=profile_lang,
            )
            profiles.append(
                {
                    "lang": profile_lang,
                    "name": profile_name,
                    "introduction": profile.introduction,
                    "keywords": [keyword.model_dump() for keyword in profile.keywords],
                    "chapters": [chapter.model_dump() for chapter in profile.chapters],
                }
            )

        souler = await create_souler_with_profiles_transactionally(
            request_id=request_id,
            wiki_id=wiki_id,
            profiles=profiles,
            aliases=aliases,
            canonical_name=canonical_name,
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
