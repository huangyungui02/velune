from __future__ import annotations

from pydantic import AliasChoices, BaseModel, Field, field_validator

from app.core.llm import PREMIUM_MODEL, complete_structured

INTRODUCTION_KEYWORD_COUNT = 5


class IntroductionKeyword(BaseModel):
    word: str
    weight: float = Field(ge=0, le=1)


class SoulerIntroduction(BaseModel):
    introduction: str = Field(
        validation_alias=AliasChoices("introduction", "int"),
    )
    keywords: list[IntroductionKeyword] = Field(
        min_length=INTRODUCTION_KEYWORD_COUNT,
        max_length=INTRODUCTION_KEYWORD_COUNT,
    )

    @field_validator("keywords")
    @classmethod
    def require_unique_keywords(cls, keywords: list[IntroductionKeyword]) -> list[IntroductionKeyword]:
        words = [keyword.word.lower() for keyword in keywords]
        if len(words) != len(set(words)):
            raise ValueError("keywords must be unique")
        return keywords


PROMPT_ZH = """# Task
根据给定的人物，给出对应的简介（introduction），以及五个关键词（keywords），以 JSON 格式返回。

# Input Example
尼采

# Output Example
{
  "introduction": "弗里德里希·尼采（Friedrich Nietzsche，1844–1900）是德国哲学家、文化批评家与诗性思想家。他最初以古典语文学者的身份进入学界，但很早便转向对西方文明根基的深度反思。他批判基督教道德与传统哲学，认为这些体系压抑了生命本能与个体力量，并提出“上帝已死”，用以指代旧有意义与价值体系的瓦解。在这种崩塌之中，人类将不可避免地面对虚无主义——即意义缺失与价值真空的处境。\\n\\n尼采并未停留在否定之中，他进一步提出“权力意志”，将其视为生命最根本的驱动力，即不断扩张、自我强化与创造的冲动。在此基础上，他区分“主人道德”与“奴隶道德”，揭示道德并非绝对真理，而是不同生命状态与权力关系的产物。\\n\\n在重建层面，尼采提出“超人”概念，象征能够摆脱既有价值、独立创造意义的人。他强调“成为你自己”，主张个体不断进行自我超越，在持续的否定与重塑中生成新的存在形态。同时，他以“永恒回归”作为极限命题：如果一个人的人生需要被无限重复，他是否仍愿意肯定它？这一思想最终指向“命运之爱”——不仅接受命运，更主动热爱一切发生过的事。\\n\\n尼采的思想具有强烈的张力与诗性表达，他并不提供稳定答案，而是通过不断的质疑、撕裂与重构，将个体推向更深层的自我审视与存在觉醒。他的影响跨越哲学、文学、心理学与现代文化，被视为理解现代性危机与个体精神困境的重要思想源头之一。",
  "keywords": [
    {"word": "虚无", "weight": 0.95},
    {"word": "超越", "weight": 0.9},
    {"word": "力量", "weight": 0.85},
    {"word": "意义", "weight": 0.8},
    {"word": "命运", "weight": 0.75}
  ]
}"""

PROMPT_EN = """# Task
Given a person, return their introduction and five keywords in JSON format.

# Input Example
Nietzsche

# Output Example
{
  "introduction": "Friedrich Nietzsche (1844-1900) was a German philosopher, cultural critic, and poetic thinker. Trained first as a classical philologist, he turned early toward a deep critique of the foundations of Western civilization. He challenged Christian morality and traditional metaphysics, arguing that inherited value systems often suppress vitality and individual strength. His famous claim that 'God is dead' marks the collapse of old structures of meaning and the rise of nihilism as a defining modern condition.\\n\\nNietzsche did not remain in negation. He developed the idea of the will to power as a basic life-drive toward expansion, self-overcoming, and creation. He contrasted master and slave moralities to show that moral systems are historically produced expressions of different life conditions and power relations, rather than timeless absolutes.\\n\\nAt the reconstructive level, he proposed the figure of the overman as one who creates values beyond inherited norms. His imperative to become who you are points to an ongoing process of transformation. Through eternal recurrence, he posed an existential test: if this life had to be lived again infinitely, could one affirm it fully? This culminates in amor fati, the love of fate.\\n\\nNietzsche's work is marked by intensity, tension, and aphoristic force. He offers no final comfort, but repeatedly pushes readers into deeper self-examination and existential awakening. His influence extends across philosophy, literature, psychology, and modern culture, and remains central to understanding modern crises of meaning and subjectivity.",
  "keywords": [
    {"word": "nihilism", "weight": 0.95},
    {"word": "self-overcoming", "weight": 0.9},
    {"word": "power", "weight": 0.85},
    {"word": "meaning", "weight": 0.8},
    {"word": "fate", "weight": 0.7}
  ]
}"""

PROMPT = {"zh": PROMPT_ZH, "en": PROMPT_EN}


async def generate_introduction(*, souler_name: str, lang: str) -> SoulerIntroduction:
    return await complete_structured(
        [
            {"role": "system", "content": PROMPT[lang]},
            {"role": "user", "content": souler_name},
        ],
        model=PREMIUM_MODEL,
        schema=SoulerIntroduction,
        temperature=0.25,
    )
