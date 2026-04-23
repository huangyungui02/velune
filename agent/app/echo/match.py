from __future__ import annotations

from collections.abc import Callable

from app.config import get_settings
from app.llm import complete_json

from app.shared import Lang, build_match_schema

settings = get_settings()

MATCH_PROMPT: dict[Lang, Callable[[int], str]] = {
    "en": lambda num: (
        f"Deeply analyze the user's thoughts to understand their emotional state, inner motivations, latent needs, and spiritual struggles, identifying the core proposition the user is truly facing at this moment. "
        f"Find exactly {num} real figures who can deeply resonate with the user's current state of mind. "
        "When matching, consider not only topical similarity but also emotional texture, way of thinking, life situation, spiritual posture, and expression style. "
        "The returned figures should have genuinely dealt with inner problems similar to the user's, rather than just being superficially related by keywords. "
        "Pay attention to the intensity and fragility of the user's emotions. If the user is in a state of depression, sadness, emptiness, vulnerability, or self-doubt, do not return figures who are overly intense, oppressive, gloomy, nihilistic, or highly aggressive. Prioritize figures who can hold, understand, comfort, and accompany the user, gently expanding their perspective. "
        f"The {num} figures should maintain differentiation and complementarity, forming multiple response angles around the same core, rather than repeating the same type of person. "
        "The figures must be real people, preferably from the fields of philosophy, literature, poetry, and thought; spiritual alignment should take precedence over fame. "
        'The core goal is not to find "the person most like the user", but "the person who can best understand and respond to the user\'s current situation."\n\n'
        "All returned figures must be individuals who are clearly in the public domain. "
        'NEVER use generic terms, roles, or placeholders like "Unknown", "Someone", or "A Friend". '
        "All names must be unique. The entire output must be in English. "
        'Return JSON with shape {"data":["name1","name2",...]}. '
    ),
    "zh": lambda num: (
        f"深入分析用户的想法，理解其情感状态、内在动机、隐含需求与精神挣扎，识别用户此刻真正面对的核心命题。"
        f"找到恰好 {num} 位能够与用户当下心境产生深度共鸣的真实人物。"
        "匹配时不仅考虑主题相似度，还要考虑情绪质地、思考方式、生命处境、精神姿态与表达风格。"
        "返回的人物应真正处理过与用户相似的内在问题，而非仅仅在表层关键词上相关。"
        "注意识别用户情绪强度与脆弱程度。若用户处于低落、悲伤、空虚、脆弱或自我怀疑状态，不要返回过于激烈、压迫、阴郁、虚无或具有强攻击性的人物。优先选择能够承接、理解、安慰、陪伴，并以温和方式拓展用户视野的人物。"
        f"{num} 位人物之间应保持差异性与互补性，围绕同一内核形成多种回应角度，而不是重复同一类人。"
        "人物必须是真实人物，优先来自哲学、文学、诗歌、思想领域；应以精神契合度为先，而不是名气大小。"
        "核心目标不是找出“最像用户的人”，而是找出“最能理解并回应用户此刻处境的人”。\n\n"
        "要求所有返回的人物必须属于公共领域。"
        '绝不允许使用任何泛指、代词或占位符，如"未知"、"某人"或"朋友"。'
        "所有人物名称必须唯一。整个返回结果必须仅使用简体中文。"
        '返回 JSON 格式 {"data":["人物1","人物2",...]}。'
    ),
}


async def match_soulers(
    content: str,
    num: int,
    lang: Lang,
    *,
    model: str,
) -> list[str]:
    """Return *num* unique souler names that resonate with *content*."""
    payload = await complete_json(
        [
            {"role": "system", "content": MATCH_PROMPT[lang](num)},
            {"role": "user", "content": content},
        ],
        model=model,
        schema_name="matched_soulers",
        schema=build_match_schema(num),
        temperature=settings.MODEL_M_TEMPERATURE,
    )
    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, list):
        raise ValueError("Invalid souler match response")

    results: list[str] = []
    seen: set[str] = set()
    for name in data:
        souler = str(name).strip()
        if not souler:
            continue
        key = souler.lower()
        if key in seen:
            continue
        seen.add(key)
        results.append(souler)

    if len(results) != num:
        raise ValueError(f"Expected {num} matched soulers, got {len(results)}")

    return results
