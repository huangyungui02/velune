from __future__ import annotations

from pydantic import BaseModel

from app.soulers.services.ai.introduction import IntroductionKeyword, generate_introduction


class SoulerProfile(BaseModel):
    introduction: str
    keywords: list[IntroductionKeyword]


async def generate_profile_content(
    *,
    canonical_name: str,
    lang: str,
) -> SoulerProfile:
    introduction = await generate_introduction(souler_name=canonical_name, lang=lang)
    return SoulerProfile(
        introduction=introduction.introduction,
        keywords=introduction.keywords,
    )
