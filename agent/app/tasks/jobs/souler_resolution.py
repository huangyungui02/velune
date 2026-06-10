from __future__ import annotations

import logging

from app.db.session import database_manager
from app.soulers.repositories.resolution import (
    complete_souler_resolution_transactionally,
    complete_existing_resolution_transactionally,
    fail_resolution,
    find_souler_by_alias,
    find_souler_by_wiki_id,
    get_souler_lang_content_state,
    is_souler_lang_content_complete,
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
        aliases: list[str | None] = [name, canonical_name]
        if wiki_id:
            by_wiki = await find_souler_by_wiki_id(wiki_id)
            if by_wiki is not None:
                souler_id = str(by_wiki["id"])
                state = await get_souler_lang_content_state(souler_id, lang)
                if is_souler_lang_content_complete(state):
                    await complete_souler_resolution_transactionally(
                        request_id=request_id,
                        souler_id=souler_id,
                        wiki_id=wiki_id,
                        lang=lang,
                        profile=None,
                        aliases=aliases,
                        canonical_name=canonical_name,
                    )
                    return {"status": "complete", "soulerId": souler_id}

                profile = await _generate_current_lang_profile(name, lang)
                souler = await complete_souler_resolution_transactionally(
                    request_id=request_id,
                    souler_id=souler_id,
                    wiki_id=wiki_id,
                    lang=lang,
                    profile=profile,
                    aliases=aliases,
                    canonical_name=canonical_name,
                )
                return {"status": "complete", "soulerId": str(souler["id"])}

        profile = await _generate_current_lang_profile(name, lang)
        souler = await complete_souler_resolution_transactionally(
            request_id=request_id,
            souler_id=None,
            wiki_id=wiki_id,
            lang=lang,
            profile=profile,
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


async def _generate_current_lang_profile(profile_name: str, lang: str) -> dict[str, object]:
    profile = await generate_profile_content(
        canonical_name=profile_name,
        fallback_name=profile_name,
        lang=lang,
    )
    return {
        "name": profile_name,
        "introduction": profile.introduction,
        "keywords": [keyword.model_dump() for keyword in profile.keywords],
        "chapters": [chapter.model_dump() for chapter in profile.chapters],
    }
