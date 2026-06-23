from __future__ import annotations

from pydantic import BaseModel

from app.soulers.services.ai.chapters import SoulerChapter, generate_chapters_content
from app.soulers.services.ai.introduction import IntroductionKeyword, generate_introduction


class SoulerProfile(BaseModel):
    introduction: str
    keywords: list[IntroductionKeyword]
    chapters: list[SoulerChapter]


async def generate_profile_content(
    *,
    name: str,
    canonical_name: str,
    lang: str,
) -> SoulerProfile:
    introduction = await generate_introduction(souler_name=canonical_name, lang=lang)
    chapters = await generate_chapters_content(souler_name=name, lang=lang)
    return SoulerProfile(
        introduction=introduction.introduction,
        keywords=introduction.keywords,
        chapters=chapters,
    )
