from __future__ import annotations

import asyncio
import json
from urllib.parse import urlencode
from urllib.request import Request, urlopen

WIKIDATA_LANG_MAP: dict[str, str] = {
    "chs": "zh",
    "en": "en",
}


def _build_search_url(name: str, wiki_lang: str) -> str:
    query = urlencode(
        {
            "action": "wbsearchentities",
            "search": name,
            "language": wiki_lang,
            "format": "json",
            "limit": "1",
        }
    )
    return f"https://www.wikidata.org/w/api.php?{query}"


def _search_first_qid_sync(name: str, lang: str) -> str | None:
    cleaned_name = name.strip()
    if not cleaned_name:
        return None

    wiki_langs = [WIKIDATA_LANG_MAP.get(lang, "en")]
    if "en" not in wiki_langs:
        wiki_langs.append("en")

    for wiki_lang in wiki_langs:
        request = Request(
            _build_search_url(cleaned_name, wiki_lang),
            headers={"User-Agent": "VeluneAgent/1.0 (https://velune.echoversa.com)"},
        )
        try:
            with urlopen(request, timeout=4.0) as response:  # noqa: S310
                payload = json.loads(response.read().decode("utf-8"))
        except Exception:  # noqa: BLE001
            continue

        results = payload.get("search", [])
        if not isinstance(results, list) or not results:
            continue

        qid = results[0].get("id")
        if isinstance(qid, str):
            cleaned_qid = qid.strip().upper()
            if cleaned_qid.startswith("Q") and cleaned_qid[1:].isdigit():
                return cleaned_qid

    return None


async def search_wikidata_qid(name: str, lang: str) -> str | None:
    return await asyncio.to_thread(_search_first_qid_sync, name, lang)
