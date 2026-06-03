from __future__ import annotations

from typing import Any

import httpx

WIKI_HEADERS = {
    "Accept": "application/json,text/plain,*/*",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "User-Agent": "VeluneSoulerResolver/1.0 (https://velune.app; contact: support@velune.app) python-httpx",
}
WIKIPEDIA_SEARCH_PATH = "/w/api.php"
WIKIPEDIA_API_PARAMS = {
    "action": "query",
    "format": "json",
    "generator": "search",
    "gsrlimit": "1",
    "prop": "pageprops",
}
WIKIDATA_API = "https://www.wikidata.org/w/api.php"


async def search_wiki_id(name: str, lang: str) -> str | None:
    host = "https://zh.wikipedia.org" if lang == "zh" else "https://en.wikipedia.org"
    params = {**WIKIPEDIA_API_PARAMS, "gsrsearch": name}
    async with httpx.AsyncClient(timeout=8.0) as client:
        response = await client.get(
            f"{host}{WIKIPEDIA_SEARCH_PATH}",
            params=params,
            headers=WIKI_HEADERS,
        )
        response.raise_for_status()
        payload = response.json()

    return _extract_wikibase_item(payload)


async def get_wikipedia_title_by_wiki_id(wiki_id: str, lang: str) -> str | None:
    entity_id = wiki_id.strip().upper()
    if not entity_id:
        return None

    params = {
        "action": "wbgetentities",
        "format": "json",
        "ids": entity_id,
        "props": "sitelinks|labels",
        "sitefilter": f"{lang}wiki",
        "languages": lang,
    }
    async with httpx.AsyncClient(timeout=8.0) as client:
        response = await client.get(WIKIDATA_API, params=params, headers=WIKI_HEADERS)
        response.raise_for_status()
        payload = response.json()

    if not _is_record(payload) or not _is_record(payload.get("entities")):
        return None
    entity = payload["entities"].get(entity_id)
    if not _is_record(entity):
        return None

    sitelinks = entity.get("sitelinks")
    if _is_record(sitelinks):
        site = sitelinks.get(f"{lang}wiki")
        if _is_record(site) and isinstance(site.get("title"), str):
            title = site["title"].strip()
            if title:
                return title

    labels = entity.get("labels")
    if _is_record(labels):
        label = labels.get(lang)
        if _is_record(label) and isinstance(label.get("value"), str):
            value = label["value"].strip()
            if value:
                return value

    return None


def _extract_wikibase_item(payload: Any) -> str | None:
    if not _is_record(payload) or not _is_record(payload.get("query")):
        return None
    pages = payload["query"].get("pages")
    if not _is_record(pages):
        return None

    for page in pages.values():
        if not _is_record(page) or not _is_record(page.get("pageprops")):
            continue
        value = page["pageprops"].get("wikibase_item")
        if isinstance(value, str):
            normalized = value.strip().upper()
            if normalized.startswith("Q") and len(normalized) > 1:
                return normalized
    return None


def _is_record(value: Any) -> bool:
    return isinstance(value, dict)
