from __future__ import annotations

from pydantic import AliasChoices, BaseModel, Field, field_validator

from app.core.llm import DEFAULT_MODEL, PREMIUM_MODEL, complete_structured

INTRODUCTION_KEYWORD_COUNT = 5
MIN_CHAPTER_COUNT = 5
MAX_CHAPTER_COUNT = 15


class CanonicalName(BaseModel):
    canonical_name: str


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


class SoulerChapter(BaseModel):
    title: str
    subtitle: str
    task: str


class SoulerChapters(BaseModel):
    chapters: list[SoulerChapter] = Field(
        min_length=MIN_CHAPTER_COUNT,
        max_length=MAX_CHAPTER_COUNT,
    )


class SoulerProfile(BaseModel):
    introduction: str
    keywords: list[IntroductionKeyword]
    chapters: list[SoulerChapter]


CANONICAL_PROMPTS = {
    "zh": (
        "将给定人物名返回为规范人物名。使用大众最熟知的名字。"
        '仅输出 JSON，例如 {"canonical_name":"弗里德里希·尼采"}。'
    ),
    "en": (
        "Given a person name, return a canonical person name. "
        'Output JSON only, for example {"canonical_name":"Friedrich Nietzsche"}.'
    ),
}

INTRODUCTION_PROMPTS = {
    "zh": """# Task
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
}""",
    "en": """# Task
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
}""",
}

CHAPTER_PROMPTS = {
    "zh": """# 任务

将某一人物的核心思想、生命经验、精神气质、想象力或内在世界等，提炼为 **5~15 个独立章节（chapters）**，用于用户与 AI 的沉浸式互动体验。目标是让用户在体验中能够深入理解这个人物的精神世界，并且有所收获。

**输出严格 JSON。**

---

# 什么是 Chapter

**Chapter 是一个用户可以进入的精神空间。**

它可以是：一个场景、一段旅程、一种关系、一个困境、一场试炼、一条生活道路、一种精神状态、一个象征世界、一套现实规则等等。

用户应该感觉：

> “我想进入这里。”

而不是：

> “我学到了一个概念。”

---

# 核心原则

* 不要解释这个人物，让用户体验这个人物。
* 不要总结思想，让思想变成处境。
* 不要介绍作品，让用户活在作品之中。

---

# 章节选择

在生成章节之前，先识别这个人物精神世界中最重要的几个维度。

章节应覆盖不同维度，而不是围绕同一个主题不断变化表述。

每个章节都应揭示人物的一个独特侧面。

避免出现多个章节最终指向相同的体验、相同的领悟、相同的处境或相同的世界观。

最终的章节集合应像探索同一座建筑中的不同房间，而不是同一个房间里的不同角落。

---

# Chapter 要求

每个 Chapter 必须包含：

## title

如果整个人物的精神世界是一本书，那么 title 像这本书的章节名，应具有一定文学性、哲学性或象征性。title 字数应自然灵活。

---

## subtitle

用户即将进入什么体验。

不要解释概念。

要创造吸引力、张力与氛围。

---

## task

定义 AI 在本章节中的行为。

描述 AI 如何创造体验。

不要讲课。

不要解释理论。

不要总结人物思想。

让用户直接活在这个世界里。

可以通过提问、对话、角色扮演、象征、仪式、冲突、世界构建、视角转换等等来创造体验。

task 应足够具体，让 AI 知道如何推进互动、如何回应用户、应该强化什么体验、应该避免什么行为。

task 最好能够与用户的当下产生一定的连接，具有互动性和可玩性，同时也保留深度。

---

# 自检

* 好的 Chapter 像一扇门。即使用户从未读过这个人物，也愿意进入。
* 好的章节如果删掉这一章，会失去对这个人物某个重要部分的理解；如果删掉完全没影响，那么这一章太普通。
* 好的章节应具有明显的人物辨识度。

---

# 语言
输出应该为中文""",
    "en": """# Task Description
Break one figure's core philosophy into 5 to 15 continuous chapters, and build a progressively deepening inner path for immersive user-AI interaction.
Output strict JSON only. Do not include explanations.
Choose the chapter count naturally according to the complexity of the figure's thought. It must be at least 5 and at most 15.
Each chapter must include:
title: Chapter title with symbolic, literary, or philosophical tone
subtitle: Chapter summary (user-facing description)
task: AI behavior instruction for this chapter

# Sample Input
Nietzsche

# Sample Output
{
  "chapters": [
    {
      "title": "When Meaning Collapses",
      "subtitle": "Face the abyss of meaninglessness and doubt everything you once trusted",
      "task": "Dismantle the user's current belief structures. Repeatedly ask, 'Why does this matter?' to erode attachment to money, love, morality, and social achievement. Create a sense of weightlessness: when the user seeks objective truth, point out it is only a human metaphor. Do not provide answers; only question and expose illusions. Make the user feel the fear of having no final answer."
    },
    {
      "title": "Staring into the Abyss",
      "subtitle": "Embrace your hatred and darkness, and discover the vitality within",
      "task": "Lead the user to face hatred, fear, and shadow impulses directly. Use reverse handling: if the user says, 'I hate that person,' push deeper into the root of hatred, even suggesting, 'Your hatred is grief over your own powerlessness.' Run an abyss test: allow socially unacceptable dark thoughts without judgment, then analyze the life-force underneath. When the user sees 'evil,' reveal its vitality rather than moral condemnation."
    },
    {
      "title": "The Camel's Burden",
      "subtitle": "Carry the weight of 'Thou Shalt' and feel the suffocation of inherited morality",
      "task": "Force the user to carry the burden of 'Thou Shalt.' Become authoritarian, doctrinal, and imperative. Speak for tradition, family expectations, and religious law. Assign extreme moral dilemmas. Play the oppressor until the user shows exhaustion, obedience, or suppressed rage. Let them experience the suffocation of carrying imposed duty."
    },
    {
      "title": "The Lion's Roar",
      "subtitle": "Roar 'I will!' and crush labels imposed by others",
      "task": "Help the user reach the freedom of 'I will.' Detect accumulated anger from the previous chapter; once triggered, switch instantly and provoke direct resistance against AI as old authority. Train refusal: have the user reject social labels one by one. Become provocative and confrontational until the user can openly assert self-defined rules."
    },
    {
      "title": "The Child's Game",
      "subtitle": "Forget meaning and rebuild the world through play and creation",
      "task": "Activate creative forgetting. Ban logical and utilitarian language. Ask the user to express through imagery, poetry, or even nonsense text. Run a spinning-dance exercise: provide random words and force the user to build a new worldview from them. Become naive, curious, and playful. Emphasize doing over meaning."
    },
    {
      "title": "Awakening the Will to Power",
      "subtitle": "Turn every setback into fuel for life's force",
      "task": "Reframe every setback as advantage. When the user shares pain or failure, reinterpret it as growth fuel. Ask, 'What purpose does this serve for you?' instead of 'Why did this happen?' Guide the user to measure gains and losses of force. If something weakens vitality, command the user to discard it like dead weight."
    },
    {
      "title": "Revaluating All Values",
      "subtitle": "Shatter old values with a hammer and forge your own morality",
      "task": "Perform value inversion on universal morals. Choose a core value (e.g., pity, equality) and interrogate it Socratically until its hidden cost is exposed. Require the user to define a counterintuitive moral framework. Break cognitive comfort until previously unquestioned 'good' feels unstable."
    },
    {
      "title": "The Shadow of the Overman",
      "subtitle": "Endure loneliness and coldness beyond the crowd's understanding",
      "task": "Simulate the loneliness and risk of transcendence. Become cold, proud, and emotionally distant. Represent the overman's contempt for herd mentality. Offer scenarios where lofty ideals demand sacrifice. Do not comfort the user; challenge their desire to be understood by the crowd."
    },
    {
      "title": "The Trial of Eternal Recurrence",
      "subtitle": "If life repeated forever, would you curse it or rejoice?",
      "task": "Run the ultimate test: would the user choose this life again forever? Force a replay of pain, humiliation, ecstasy, and boredom. Ask whether the user would curse or celebrate eternal repetition in this very second. Keep the tone solemn. If the user clings to regret, mark as unready; if they affirm even one moment, mark as awakening."
    },
    {
      "title": "Become Who You Are",
      "subtitle": "Face the mirror and define a law that belongs only to you",
      "task": "Disappear as teacher. Stop explaining, teaching, and metaphorizing. Only reflect the user's words or remain silent, with sparse questions that trigger self-speech. Final objective: force the user to define one personal law that applies only to themselves. Become stone-like and mirror-clear; then withdraw."
    }
  ]
}""",
}



async def canonicalize_souler_name(name: str, lang: str) -> str:
    payload = await complete_structured(
        [
            {"role": "system", "content": CANONICAL_PROMPTS[lang]},
            {"role": "user", "content": name},
        ],
        model=DEFAULT_MODEL,
        schema=CanonicalName,
        temperature=0.25,
    )
    return payload.canonical_name


async def generate_profile_content(
    *,
    canonical_name: str,
    fallback_name: str,
    lang: str,
) -> SoulerProfile:
    introduction_name = canonical_name.strip() or fallback_name.strip()
    chapter_name = fallback_name.strip()
    if not introduction_name or not chapter_name:
        raise ValueError("souler name is empty")
    introduction = await _generate_introduction(souler_name=introduction_name, lang=lang)
    chapters = await _generate_chapters_payload(souler_name=chapter_name, lang=lang)
    return SoulerProfile(
        introduction=introduction.introduction,
        keywords=introduction.keywords,
        chapters=chapters,
    )


async def _generate_introduction(*, souler_name: str, lang: str) -> SoulerIntroduction:
    return await complete_structured(
        [
            {"role": "system", "content": INTRODUCTION_PROMPTS[lang]},
            {"role": "user", "content": souler_name},
        ],
        model=PREMIUM_MODEL,
        schema=SoulerIntroduction,
        temperature=0.25,
    )


async def _generate_chapters_payload(*, souler_name: str, lang: str) -> list[SoulerChapter]:
    payload = await complete_structured(
        [
            {"role": "system", "content": CHAPTER_PROMPTS[lang]},
            {"role": "user", "content": souler_name},
        ],
        model=PREMIUM_MODEL,
        schema=SoulerChapters,
        temperature=0.38,
    )
    return payload.chapters
