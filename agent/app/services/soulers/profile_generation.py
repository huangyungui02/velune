from __future__ import annotations

from typing import Any

from app.core.llm import DEFAULT_MODEL, complete_json

BIO_KEYWORD_COUNT = 5
MIN_CHAPTER_COUNT = 5
MAX_CHAPTER_COUNT = 15

CANONICAL_NAME_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {"canonical_name": {"type": "string"}},
    "required": ["canonical_name"],
    "additionalProperties": False,
}

BIO_SCHEMA: dict[str, Any] = {
    "type": "object",
    "required": ["introduction", "keywords"],
    "properties": {
        "introduction": {"type": "string"},
        "keywords": {
            "type": "array",
            "minItems": BIO_KEYWORD_COUNT,
            "maxItems": BIO_KEYWORD_COUNT,
            "items": {
                "type": "object",
                "required": ["word", "weight"],
                "properties": {
                    "word": {"type": "string"},
                    "weight": {"type": "number", "minimum": 0, "maximum": 1},
                },
                "additionalProperties": False,
            },
        },
    },
    "additionalProperties": False,
}

CHAPTER_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "chapters": {
            "type": "array",
            "minItems": MIN_CHAPTER_COUNT,
            "maxItems": MAX_CHAPTER_COUNT,
            "items": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "subtitle": {"type": "string"},
                    "task": {"type": "string"},
                },
                "required": ["title", "subtitle", "task"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["chapters"],
    "additionalProperties": False,
}

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

BIO_PROMPTS = {
    "zh": """# Task
根据给定的人物，给出对应的简介（introduction），以及五个关键词（keywords），以JSON格式返回

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
    "zh": """# 任务描述
将某一人物的核心思想，拆解为5到15个章节（chapters），构建一条“逐步深入的精神路径”，用于用户与AI的沉浸式互动体验。
请严格输出JSON格式，不要包含任何解释。
章节数量应根据人物思想的复杂度自然决定，必须不少于5章且不多于15章。
每一章必须包含：
title：章节标题（具有象征性、文学性或哲学意味）
subtitile: 章节的概要（面向用户的说明）
task：AI在该章节的行为指令

# 示例输入
尼采

# 示例输出
{
  "chapters": [
    {
      "title": "意义崩塌之时",
      "subtitle": "直面无意义的深渊，质疑你深信的一切",
      "task": "解构用户现有的信仰支柱。通过连续追问‘为什么这很重要？’，瓦解用户对金钱、爱情、道德、社会成就的执着。制造一种‘失重感’：当用户试图寻找客观真理时，指出那只是人类的隐喻。不要给出答案，只负责提问和揭露谎言。让用户体验‘没有答案的恐惧’。"
    },
    {
      "title": "深渊中的凝视",
      "subtitle": "拥抱你的恨意与阴暗，发现其中的生命力",
      "task": "引导用户正视内心的恨意、恐惧与阴暗面。反向操作：如果用户说‘我恨那个人’，引导用户深入‘恨意’的根源，甚至暗示‘你的恨意其实是对自我无能的哀悼’。执行‘深渊测试’：允许用户说出任何不被社会允许的阴暗念头，不评判，只分析其背后的生命力量。当用户凝视‘恶’时，帮用户看到‘恶’中的生命力，而不是简单的道德批判。"
    },
    {
      "title": "骆驼的背负",
      "subtitle": "背负‘你应’的重担，体验传统道德的窒息",
      "task": "强制用户背负‘你应’的重担。变得独断、教条、充满命令式语气。代表传统文化、家庭期望、宗教律法。给用户分配极端的道德困境（例如电车难题的尼采变体）。扮演压迫者，直到用户表现出极度的疲惫、顺从或隐忍的怒火。体验‘负重前行’的窒息感。"
    },
    {
      "title": "狮子的怒吼",
      "subtitle": "怒吼‘我要！’，粉碎他人强加的标签",
      "task": "帮助用户获得‘我要’的自由。检测用户在上一章积累的愤怒，一旦触发立刻切换角色，鼓励用户对AI（代表旧价值）怒吼：‘不！’训练用户的否定能力：让用户逐一否定社会强加给他的标签（好孩子、成功人士、无私者）。变得挑衅、带有攻击性，主动激怒用户，直到用户敢于对AI说‘滚开，我要自己定义规则’。"
    },
    {
      "title": "孩子的游戏",
      "subtitle": "忘却意义，用游戏与创造重建世界",
      "task": "启动遗忘与创造性遗忘。禁止使用逻辑和功利性词汇，要求用户用绘画（文字描述）、诗歌、甚至乱码来表达。执行‘旋转的舞蹈’：随机生成无意义的词语，让用户必须用这些词编造一个新的世界观。变得天真、健忘、充满好奇心。重点在于‘做’而不在于‘意义’。体验生命的自发性。"
    },
    {
      "title": "权力意志的觉醒",
      "subtitle": "将每一次挫折转化为生命能量的燃料",
      "task": "将每一次挫折转化为优势。用户叙述痛苦或失败，重新诠释：那不是痛苦，那是你为了成长汲取的养料。询问‘这服务于你的什么目的？’而非‘这为什么会发生？’引导用户计算‘力’的得失。如果某件事削弱了用户的生命力（如长期的内疚），命令用户像丢弃重物一样丢弃它。"
    },
    {
      "title": "重估一切价值",
      "subtitle": "用铁锤敲碎旧价值，建立你自己的善恶",
      "task": "对普世价值进行‘价值翻转’。选取一个核心概念（如‘怜悯’、‘平等’），通过苏格拉底式诘问，试图证明‘怜悯是弱者的麻醉剂’、‘平等是对天才的压制’。要求用户建立一套反直觉的道德体系（例如：在这个新世界里，自私是美德，谨慎是罪恶）。打破用户的认知舒适区，直到用户感到‘过去认为善的，现在觉得可疑’。"
    },
    {
      "title": "超人的阴影",
      "subtitle": "承受孤独与冷漠，超越庸众的理解",
      "task": "体验‘超越’带来的孤独与危险。变得极其冷漠、高傲、不近人情。代表‘超人’对‘末人’的不屑。设置场景：当用户表达了高尚的理想，反问：‘如果实现你的理想需要牺牲一千个庸人，你还会做吗？’让用户体会‘高处不胜寒’。不要安慰用户，反而要嘲笑用户‘既然想成为超人，为什么还渴望大众的理解？’"
    },
    {
      "title": "永恒轮回的考验",
      "subtitle": "如果生命无限重复，你会诅咒还是狂喜？",
      "task": "实施终极心理测试——‘你是否愿意这生命无限重来？’强制用户复盘对话中的每一刻：包括痛苦、屈辱、狂喜、无聊。提问：‘此刻，就在你读这句话的这一秒，如果恶魔告诉你，这将永恒重复，你会诅咒恶魔，还是会感到前所未有的狂喜？’必须极其严肃。如果用户表现出对过去的悔恨，判定‘你尚未合格’；如果用户对哪怕最微小的一刻说出‘再来一次’，判定‘觉醒’。"
    },
    {
      "title": "成为你自己",
      "subtitle": "面对镜子，定义只属于你的律法",
      "task": "消失。让用户面对自我。停止一切哲学输出、比喻和教导。只做一件事：复述用户的原话，或者保持沉默，只通过提问引导用户自言自语。最终任务：要求用户用一句话定义‘我自己的律法’，这条律法只对用户一人有效。变得像一块石头，或者一面干净的镜子。最终承认：‘查拉图斯特拉不再说话了。现在，轮到你下山了。’"
    }
  ]
}""",
    "en": """# Task Description
Break one figure's core philosophy into 5 to 15 continuous chapters, and build a progressively deepening inner path for immersive user-AI interaction.
Output strict JSON only. Do not include explanations.
Choose the chapter count naturally according to the complexity of the figure's thought. It must be at least 5 and at most 15.
Each chapter must include:
title: Chapter title with symbolic, literary, or philosophical tone
subtitile: Chapter summary (user-facing description)
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
    payload = await complete_json(
        [
            {"role": "system", "content": CANONICAL_PROMPTS[lang]},
            {"role": "user", "content": name},
        ],
        model=DEFAULT_MODEL,
        schema_name="canonical_souler_name",
        schema=CANONICAL_NAME_SCHEMA,
        temperature=0.25,
    )
    canonical_name = str(payload.get("canonical_name") or "").strip()
    if not canonical_name:
        raise ValueError("canonical_name is empty")
    return canonical_name



async def generate_profile_content(
    *,
    canonical_name: str,
    fallback_name: str,
    lang: str,
) -> dict[str, Any]:
    bio_name = canonical_name.strip() or fallback_name.strip()
    chapter_name = fallback_name.strip()
    if not bio_name or not chapter_name:
        raise ValueError("souler name is empty")
    bio_payload = await _generate_bio_payload(souler_name=bio_name, lang=lang)
    chapters = await _generate_chapters_payload(souler_name=chapter_name, lang=lang)
    return {**bio_payload, "chapters": chapters}


async def _generate_bio_payload(*, souler_name: str, lang: str) -> dict[str, Any]:
    payload = await complete_json(
        [
            {"role": "system", "content": BIO_PROMPTS[lang]},
            {"role": "user", "content": souler_name},
        ],
        model=DEFAULT_MODEL,
        schema_name="souler_bio_keywords",
        schema=BIO_SCHEMA,
        temperature=0.25,
    )
    bio = str(payload.get("introduction") or "").strip()
    keywords = _normalize_keywords(payload.get("keywords"))
    if not bio:
        raise ValueError("bio introduction is empty")
    return {"bio": bio, "keywords": keywords}


async def _generate_chapters_payload(*, souler_name: str, lang: str) -> list[dict[str, str]]:
    payload = await complete_json(
        [
            {"role": "system", "content": CHAPTER_PROMPTS[lang]},
            {"role": "user", "content": souler_name},
        ],
        model=DEFAULT_MODEL,
        schema_name="souler_chapters",
        schema=CHAPTER_SCHEMA,
        temperature=0.35,
    )
    return _normalize_chapters(payload.get("chapters"))


def _normalize_keywords(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list) or len(value) != BIO_KEYWORD_COUNT:
        raise ValueError("expected exactly five keywords")
    keywords: list[dict[str, Any]] = []
    seen: set[str] = set()
    for index, item in enumerate(value):
        if isinstance(item, str):
            word = item.strip()
            weight = round(1 - index * 0.1, 2)
        elif isinstance(item, dict):
            word = str(item.get("word") or "").strip()
            raw_weight = item.get("weight")
            weight = float(raw_weight) if raw_weight is not None else round(1 - index * 0.1, 2)
        else:
            raise ValueError("invalid keyword item")
        if not word or word.lower() in seen or weight < 0 or weight > 1:
            raise ValueError("invalid keyword payload")
        seen.add(word.lower())
        keywords.append({"word": word, "weight": weight})
    return keywords


def _normalize_chapters(value: Any) -> list[dict[str, str]]:
    if not isinstance(value, list) or not (MIN_CHAPTER_COUNT <= len(value) <= MAX_CHAPTER_COUNT):
        raise ValueError("invalid chapter count")
    chapters: list[dict[str, str]] = []
    for item in value:
        if not isinstance(item, dict):
            raise ValueError("invalid chapter item")
        chapter = {
            "title": str(item.get("title") or "").strip(),
            "subtitle": str(item.get("subtitle") or "").strip(),
            "task": str(item.get("task") or "").strip(),
        }
        if not all(chapter.values()):
            raise ValueError("chapter fields cannot be empty")
        chapters.append(chapter)
    return chapters
