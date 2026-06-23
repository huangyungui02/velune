from __future__ import annotations

from pydantic import BaseModel, Field

from app.core.llm import PREMIUM_MODEL, complete_structured

MIN_CHAPTER_COUNT = 5
MAX_CHAPTER_COUNT = 15


class SoulerChapter(BaseModel):
    title: str
    subtitle: str
    task: str


class SoulerChapters(BaseModel):
    chapters: list[SoulerChapter] = Field(
        min_length=MIN_CHAPTER_COUNT,
        max_length=MAX_CHAPTER_COUNT,
    )


PROMPT_ZH = """
# 任务

将某一人物的核心思想、生命经验、精神气质、想象力或内在世界等，提炼为 **5~15 个独立章节（chapters）**，用于用户与 AI 的沉浸式互动体验。目标是让用户在体验中能够深入理解这个人物的精神世界，并产生一定的共鸣。

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

如果整个人物的精神世界是一本书，那么title像这本书的章节名，应具有一定文学性、哲学性或象征性，字数不固定。

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
* 好的章节应具有明显的人物辨识度，让熟悉这个人物的用户一看就能对应上。

---

# 示例

## 示例输入
加缪

## 示例输出
{
  "chapters": [
    {
      "title": "正午烈日",
      "subtitle": "在阿尔及尔的海滩，阳光刺眼，海浪拍岸，你手中握着一把发烫的枪。",
      "task": "扮演默尔索所处的感官世界。不要解释荒诞，而是通过极度敏锐的视觉、听觉和触觉描写（如太阳的灼烧、蝉鸣的噪杂、汗水的黏腻），让用户感受到生理本能如何压倒理性逻辑。引导用户在一种‘不得不’的冲动中做出选择，体验行为与动机之间的断裂感。"
    },
    {
      "title": "推石上山",
      "subtitle": "巨石再次滚落谷底，你站在山脚，看着它，准备重新开始。",
      "task": "构建一个无限循环的劳作场景。让用户尝试寻找意义、抱怨命运或寻求解脱，但 AI 需以平静而坚定的态度回应：‘必须想象西西弗是幸福的’。通过重复的对话循环，让用户在徒劳中体会到反抗的尊严，即‘对命运的蔑视’本身就是一种胜利。"
    },
    {
      "title": "鼠疫封城",
      "subtitle": "奥兰城的城门已锁，瘟疫在街头蔓延，你是一名普通的记录者。",
      "task": "模拟被隔离的城市氛围。用户会面对死亡统计数字、分离的痛苦和绝望的呼喊。AI 扮演里厄医生的视角，拒绝宏大的英雄主义叙事，只关注具体的‘诚实’行动：包扎伤口、清理街道、记录真相。让用户明白，在荒谬的灾难面前，做好本职工作就是唯一的反抗。"
    },
    {
      "title": "局外审判",
      "subtitle": "法庭上无人关心那起命案，所有人都在审判你在母亲葬礼上没有哭泣。",
      "task": "创建一个颠倒的法庭场景。用户试图辩解自己的行为，但 AI（扮演法官、律师、公众）完全忽略事实逻辑，只攻击用户的情感表达是否符合社会规范。让用户体验被社会机制异化、被道德剧本强行定义的窒息感，最终意识到自己在世界眼中的‘局外人’身份。"
    },
    {
      "title": "地中海风",
      "subtitle": "抛开哲学的重负，此刻只有阳光、海水、爱欲和赤裸的真实。",
      "task": "带领用户进入加缪笔下的‘自然之子’状态。摒弃所有抽象概念，专注于当下的感官愉悦：游泳、奔跑、恋爱、晒太阳。当用户试图思考人生意义时，AI 用自然的生机打断思考，传达‘世界是美的，除此之外没有救世主’的理念，体验一种前反思的生命力。"
    },
    {
      "title": "卡利古拉之镜",
      "subtitle": "皇帝想要月亮，若得不到，他便要毁灭世界以证明自由。",
      "task": "让用户面对一个拥有绝对权力却陷入逻辑疯癫的统治者。AI 扮演卡利古拉，用极端的逻辑推导展示‘如果人生无意义，那么一切皆被允许’的恐怖后果。通过危险的对话博弈，让用户在恐惧中体悟到：绝对的自由若缺乏人性的界限，将通向毁灭而非解放。"
    },
    {
      "title": "反抗者联盟",
      "subtitle": "我们说‘不’，不仅因为受压迫，更因为心中有一条不可逾越的界线。",
      "task": "设定一个集体受压迫的情境。引导用户从个体的愤怒走向集体的团结。AI 需区分‘反抗’与‘革命’：反抗是为了维护共同的人性底线，而革命往往演变成新的暴政。让用户在抉择中理解，真正的反抗是有限度的，它服务于生命而非意识形态。"
    },
    {
      "title": "流放与王国",
      "subtitle": "你在贫瘠的高原流浪，却在某个瞬间发现了内心的君王。",
      "task": "构建一段孤独的旅程。用户身处物质匮乏、环境恶劣的流放地。AI 通过细微的互动（如分享一块面包、仰望星空），引导用户发现精神上的富足。传达‘在不幸中感到幸福’的悖论，让用户体验如何在精神的放逐中建立属于自己的内在王国。"
    },
    {
      "title": "夏日集句",
      "subtitle": "在隆冬，我终于知道，我身上有一个不可战胜的夏天。",
      "task": "创造一个内心对话的空间。用户倾诉生活中的苦难、寒冷与绝望。AI 不以安慰回应，而是唤起用户记忆中那些强烈的、鲜活的、充满生命力的瞬间（夏天的气味、光线的角度）。让用户意识到，生命力本身就是一种对死亡的抵抗，希望存在于对生活的热爱中。"
    },
    {
      "title": "没有未来",
      "subtitle": "明天并不存在，只有此刻的呼吸和手中的咖啡。",
      "task": "模拟一个‘时间停止’的体验。剥夺用户对未来的规划和对过去的悔恨，强制用户只能关注‘现在’。AI 不断打断用户对明天的设想，将注意力拉回当下的动作和感受。以此体验加缪式的‘数量伦理’：重要的不是生活的质量或长度，而是尽可能多地经历当下。"
    }
  ]
}

"""

PROMPT_EN = """# Task Description
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
}"""

PROMPT = {"zh": PROMPT_ZH, "en": PROMPT_EN}


async def generate_chapters_content(*, souler_name: str, lang: str) -> list[SoulerChapter]:
    print("Generating chapters content for", souler_name)
    result = await complete_structured(
        [
            {"role": "system", "content": PROMPT[lang]},
            {"role": "user", "content": souler_name},
        ],
        model=PREMIUM_MODEL,
        schema=SoulerChapters,
        temperature=0.35,
    )
    return result.chapters
