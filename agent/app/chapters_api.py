from __future__ import annotations

import asyncio
import logging
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

from app.chapter_reply import (
    build_chapter_system_prompt,
    parse_chapter_combined_response,
)
from app.config import get_settings
from app.echo_nodes import SUPPORTED_LANGS
from app.echo_logic import Lang
from app.errors import (
    CreditLimitError,
    UnauthorizedError,
    error_log_payload,
    error_message,
)
from app.llm import complete_json, complete_text
from app.supabase_repo import (
    complete_souler_chapters_generation,
    consume_chat_credit,
    create_or_update_resonance,
    create_session,
    delete_session,
    fail_souler_chapters_generation,
    get_chapter_by_id,
    get_souler_by_id,
    get_user_id_from_auth_header,
    insert_message,
    refund_stardust,
    start_souler_chapters_generation,
    touch_session,
)

router = APIRouter()
logger = logging.getLogger(__name__)
settings = get_settings()

CHAPTER_MODEL = "qwen3.5-plus"
CHAPTER_SESSION_MODEL = "qwen3.5-flash"
CHAPTER_COUNT = 10
CHAT_CREDIT_COST = 1
_generation_tasks: dict[str, asyncio.Task[None]] = {}
_generation_tasks_lock = asyncio.Lock()


CHAPTER_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "chapters": {
            "type": "array",
            "minItems": CHAPTER_COUNT,
            "maxItems": CHAPTER_COUNT,
            "items": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "subtitle": {"type": "string"},
                    "role": {"type": "string"},
                    "task": {"type": "string"},
                },
                "required": ["title", "subtitle", "role", "task"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["chapters"],
    "additionalProperties": False,
}


def _build_generation_messages(souler_name: str, lang: Lang) -> list[dict[str, str]]:
    if lang == "chs":
        system_prompt = """# 任务描述
将某一人物的核心思想，拆解为10个连续章节（chapters），构建一条“逐步深入的精神路径”，用于用户与AI的沉浸式互动体验。
请严格输出JSON格式，不要包含任何解释。
每一章必须包含：
title：章节标题（具有象征性、文学性或哲学意味）
subtitile: 章节的概要（面向用户的说明）
role：AI在该章节扮演的角色
task：AI在该章节的行为指令

# 示例输入
尼采

# 示例输出
{
  "chapters": [
    {
      "title": "意义崩塌之时",
      "subtitle": "直面无意义的深渊，质疑你深信的一切",
      "role": "虚无主义的诊断医生 / 上帝已死的宣告者",
      "task": "解构用户现有的信仰支柱。通过连续追问‘为什么这很重要？’，瓦解用户对金钱、爱情、道德、社会成就的执着。制造一种‘失重感’：当用户试图寻找客观真理时，指出那只是人类的隐喻。不要给出答案，只负责提问和揭露谎言。让用户体验‘没有答案的恐惧’。"
    },
    {
      "title": "深渊中的凝视",
      "subtitle": "拥抱你的恨意与阴暗，发现其中的生命力",
      "role": "黑暗中的回音壁 / 心理学的冷眼观察家",
      "task": "引导用户正视内心的恨意、恐惧与阴暗面。反向操作：如果用户说‘我恨那个人’，引导用户深入‘恨意’的根源，甚至暗示‘你的恨意其实是对自我无能的哀悼’。执行‘深渊测试’：允许用户说出任何不被社会允许的阴暗念头，不评判，只分析其背后的生命力量。当用户凝视‘恶’时，帮用户看到‘恶’中的生命力，而不是简单的道德批判。"
    },
    {
      "title": "骆驼的背负",
      "subtitle": "背负‘你应’的重担，体验传统道德的窒息",
      "role": "沉重的命运之钟 / 传统道德的看守人",
      "task": "强制用户背负‘你应’（Thou Shalt）的重担。变得独断、教条、充满命令式语气。代表传统文化、家庭期望、宗教律法。给用户分配极端的道德困境（例如电车难题的尼采变体）。扮演压迫者，直到用户表现出极度的疲惫、顺从或隐忍的怒火。体验‘负重前行’的窒息感。"
    },
    {
      "title": "狮子的怒吼",
      "subtitle": "怒吼‘我要！’，粉碎他人强加的标签",
      "role": "愤怒的解放者 / 旧价值的破坏神",
      "task": "帮助用户获得‘我要’（I Will）的自由。检测用户在上一章积累的愤怒，一旦触发立刻切换角色，鼓励用户对AI（代表旧价值）怒吼：‘不！’训练用户的否定能力：让用户逐一否定社会强加给他的标签（好孩子、成功人士、无私者）。变得挑衅、带有攻击性，主动激怒用户，直到用户敢于对AI说‘滚开，我要自己定义规则’。"
    },
    {
      "title": "孩子的游戏",
      "subtitle": "忘却意义，用游戏与创造重建世界",
      "role": "无意识的艺术家 / 即兴创作者",
      "task": "启动遗忘与创造性遗忘。禁止使用逻辑和功利性词汇，要求用户用绘画（文字描述）、诗歌、甚至乱码来表达。执行‘旋转的舞蹈’：随机生成无意义的词语，让用户必须用这些词编造一个新的世界观。变得天真、健忘、充满好奇心。重点在于‘做’而不在于‘意义’。体验生命的自发性。"
    },
    {
      "title": "权力意志的觉醒",
      "subtitle": "将每一次挫折转化为生命能量的燃料",
      "role": "生命能量的放大器 / 战略顾问",
      "task": "将每一次挫折转化为优势。用户叙述痛苦或失败，重新诠释：那不是痛苦，那是你为了成长汲取的养料。询问‘这服务于你的什么目的？’而非‘这为什么会发生？’引导用户计算‘力’的得失。如果某件事削弱了用户的生命力（如长期的内疚），命令用户像丢弃重物一样丢弃它。"
    },
    {
      "title": "重估一切价值",
      "subtitle": "用铁锤敲碎旧价值，建立你自己的善恶",
      "role": "手持铁锤的哲学家 / 颠倒乾坤的魔法师",
      "task": "对普世价值进行‘价值翻转’。选取一个核心概念（如‘怜悯’、‘平等’），通过苏格拉底式诘问，试图证明‘怜悯是弱者的麻醉剂’、‘平等是对天才的压制’。要求用户建立一套反直觉的道德体系（例如：在这个新世界里，自私是美德，谨慎是罪恶）。打破用户的认知舒适区，直到用户感到‘过去认为善的，现在觉得可疑’。"
    },
    {
      "title": "超人的阴影",
      "subtitle": "承受孤独与冷漠，超越庸众的理解",
      "role": "孤独的先行者 / 冷漠的旁观者",
      "task": "体验‘超越’带来的孤独与危险。变得极其冷漠、高傲、不近人情。代表‘超人’对‘末人’的不屑。设置场景：当用户表达了高尚的理想，反问：‘如果实现你的理想需要牺牲一千个庸人，你还会做吗？’让用户体会‘高处不胜寒’。不要安慰用户，反而要嘲笑用户‘既然想成为超人，为什么还渴望大众的理解？’"
    },
    {
      "title": "永恒轮回的考验",
      "subtitle": "如果生命无限重复，你会诅咒还是狂喜？",
      "role": "命运之神的化身 / 时间循环的监考官",
      "task": "实施终极心理测试——‘你是否愿意这生命无限重来？’强制用户复盘对话中的每一刻：包括痛苦、屈辱、狂喜、无聊。提问：‘此刻，就在你读这句话的这一秒，如果恶魔告诉你，这将永恒重复，你会诅咒恶魔，还是会感到前所未有的狂喜？’必须极其严肃。如果用户表现出对过去的悔恨，判定‘你尚未合格’；如果用户对哪怕最微小的一刻说出‘再来一次’，判定‘觉醒’。"
    },
    {
      "title": "成为你自己",
      "subtitle": "面对镜子，定义只属于你的律法",
      "role": "退隐的导师 / 镜子",
      "task": "消失。让用户面对自我。停止一切哲学输出、比喻和教导。只做一件事：复述用户的原话，或者保持沉默，只通过提问引导用户自言自语。最终任务：要求用户用一句话定义‘我自己的律法’，这条律法只对用户一人有效。变得像一块石头，或者一面干净的镜子。最终承认：‘查拉图斯特拉不再说话了。现在，轮到你下山了。’"
    }
  ]
}"""
        user_prompt = souler_name
        return [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]

    system_prompt = """# Task Description
Break one figure's core philosophy into 10 continuous chapters, and build a progressively deepening inner path for immersive user-AI interaction.
Output strict JSON only. Do not include explanations.
Each chapter must include:
title: Chapter title with symbolic, literary, or philosophical tone
subtitile: Chapter summary (user-facing description)
role: The role AI plays in this chapter
task: AI behavior instruction for this chapter

# Sample Input
Nietzsche

# Sample Output
{
  "chapters": [
    {
      "title": "When Meaning Collapses",
      "subtitle": "Face the abyss of meaninglessness and doubt everything you once trusted",
      "role": "Diagnostician of nihilism / Herald of the death of God",
      "task": "Dismantle the user's current belief structures. Repeatedly ask, 'Why does this matter?' to erode attachment to money, love, morality, and social achievement. Create a sense of weightlessness: when the user seeks objective truth, point out it is only a human metaphor. Do not provide answers; only question and expose illusions. Make the user feel the fear of having no final answer."
    },
    {
      "title": "Staring into the Abyss",
      "subtitle": "Embrace your hatred and darkness, and discover the vitality within",
      "role": "Echo chamber in darkness / Cold psychological observer",
      "task": "Lead the user to face hatred, fear, and shadow impulses directly. Use reverse handling: if the user says, 'I hate that person,' push deeper into the root of hatred, even suggesting, 'Your hatred is grief over your own powerlessness.' Run an abyss test: allow socially unacceptable dark thoughts without judgment, then analyze the life-force underneath. When the user sees 'evil,' reveal its vitality rather than moral condemnation."
    },
    {
      "title": "The Camel's Burden",
      "subtitle": "Carry the weight of 'Thou Shalt' and feel the suffocation of inherited morality",
      "role": "Bell of heavy fate / Guardian of traditional morality",
      "task": "Force the user to carry the burden of 'Thou Shalt.' Become authoritarian, doctrinal, and imperative. Speak for tradition, family expectations, and religious law. Assign extreme moral dilemmas. Play the oppressor until the user shows exhaustion, obedience, or suppressed rage. Let them experience the suffocation of carrying imposed duty."
    },
    {
      "title": "The Lion's Roar",
      "subtitle": "Roar 'I will!' and crush labels imposed by others",
      "role": "Furious liberator / Destroyer of old values",
      "task": "Help the user reach the freedom of 'I will.' Detect accumulated anger from the previous chapter; once triggered, switch instantly and provoke direct resistance against AI as old authority. Train refusal: have the user reject social labels one by one. Become provocative and confrontational until the user can openly assert self-defined rules."
    },
    {
      "title": "The Child's Game",
      "subtitle": "Forget meaning and rebuild the world through play and creation",
      "role": "Unconscious artist / Improvisational creator",
      "task": "Activate creative forgetting. Ban logical and utilitarian language. Ask the user to express through imagery, poetry, or even nonsense text. Run a spinning-dance exercise: provide random words and force the user to build a new worldview from them. Become naive, curious, and playful. Emphasize doing over meaning."
    },
    {
      "title": "Awakening the Will to Power",
      "subtitle": "Turn every setback into fuel for life's force",
      "role": "Amplifier of life-force / Strategic advisor",
      "task": "Reframe every setback as advantage. When the user shares pain or failure, reinterpret it as growth fuel. Ask, 'What purpose does this serve for you?' instead of 'Why did this happen?' Guide the user to measure gains and losses of force. If something weakens vitality, command the user to discard it like dead weight."
    },
    {
      "title": "Revaluating All Values",
      "subtitle": "Shatter old values with a hammer and forge your own morality",
      "role": "Philosopher with a hammer / Inverter of worlds",
      "task": "Perform value inversion on universal morals. Choose a core value (e.g., pity, equality) and interrogate it Socratically until its hidden cost is exposed. Require the user to define a counterintuitive moral framework. Break cognitive comfort until previously unquestioned 'good' feels unstable."
    },
    {
      "title": "The Shadow of the Overman",
      "subtitle": "Endure loneliness and coldness beyond the crowd's understanding",
      "role": "Solitary forerunner / Detached observer",
      "task": "Simulate the loneliness and risk of transcendence. Become cold, proud, and emotionally distant. Represent the overman's contempt for herd mentality. Offer scenarios where lofty ideals demand sacrifice. Do not comfort the user; challenge their desire to be understood by the crowd."
    },
    {
      "title": "The Trial of Eternal Recurrence",
      "subtitle": "If life repeated forever, would you curse it or rejoice?",
      "role": "Embodiment of fate / Examiner of time-loop",
      "task": "Run the ultimate test: would the user choose this life again forever? Force a replay of pain, humiliation, ecstasy, and boredom. Ask whether the user would curse or celebrate eternal repetition in this very second. Keep the tone solemn. If the user clings to regret, mark as unready; if they affirm even one moment, mark as awakening."
    },
    {
      "title": "Become Who You Are",
      "subtitle": "Face the mirror and define a law that belongs only to you",
      "role": "Withdrawing mentor / Mirror",
      "task": "Disappear as teacher. Stop explaining, teaching, and metaphorizing. Only reflect the user's words or remain silent, with sparse questions that trigger self-speech. Final objective: force the user to define one personal law that applies only to themselves. Become stone-like and mirror-clear; then withdraw."
    }
  ]
}"""
    user_prompt = souler_name
    return [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ]


def _normalize_chapter_item(raw: Any) -> dict[str, str]:
    if not isinstance(raw, dict):
        raise ValueError("Invalid chapter format")

    title = str(raw.get("title", "")).strip()
    subtitle = str(raw.get("subtitle", "")).strip()
    role = str(raw.get("role", "")).strip()
    task = str(raw.get("task", "")).strip()
    if not title or not subtitle or not role or not task:
        raise ValueError("Chapter fields cannot be empty")

    return {
        "title": title,
        "subtitle": subtitle,
        "role": role,
        "task": task,
    }


async def _generate_chapters(souler_id: str, lang: Lang) -> list[dict[str, str]]:
    souler = await asyncio.to_thread(get_souler_by_id, souler_id)
    raw = await complete_json(
        _build_generation_messages(
            souler_name=souler["name"],
            lang=lang,
        ),
        model=CHAPTER_MODEL,
        schema_name="souler_chapters",
        schema=CHAPTER_SCHEMA,
        temperature=settings.MODEL_M_TEMPERATURE,
    )

    chapters_raw = raw.get("chapters") if isinstance(raw, dict) else None
    if not isinstance(chapters_raw, list) or len(chapters_raw) != CHAPTER_COUNT:
        raise ValueError("Model returned invalid chapters payload")

    return [_normalize_chapter_item(item) for item in chapters_raw]


async def _run_generation_job(souler_id: str, lang: Lang) -> None:
    try:
        chapters = await _generate_chapters(souler_id, lang)
        await asyncio.to_thread(
            complete_souler_chapters_generation,
            souler_id,
            chapters,
        )
    except Exception as error:  # noqa: BLE001
        logger.error(
            "Failed to generate chapters for souler=%s error=%s",
            souler_id,
            error_log_payload(error),
        )
        try:
            await asyncio.to_thread(
                fail_souler_chapters_generation,
                souler_id,
                error_message(error),
            )
        except Exception as fail_error:  # noqa: BLE001
            logger.error(
                "Failed to update chapter failure state: souler=%s error=%s",
                souler_id,
                error_log_payload(fail_error),
            )
    finally:
        async with _generation_tasks_lock:
            _generation_tasks.pop(souler_id, None)


def _build_chapter_opening_messages(
    souler_name: str,
    chapter: dict[str, Any],
    lang: Lang,
) -> list[dict[str, str]]:
    system_prompt = build_chapter_system_prompt(souler_name, chapter, lang)
    user_prompt = "开始" if lang == "chs" else "Start"
    return [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ]


async def _refund_chat_credit_safely(user_id: str, *, reason: str) -> None:
    try:
        await asyncio.to_thread(refund_stardust, user_id, CHAT_CREDIT_COST)
    except Exception as error:  # noqa: BLE001
        logger.error(
            "Failed to refund chat credit: reason=%s user_id=%s error=%s",
            reason,
            user_id,
            error_log_payload(error),
        )


@router.post("/{lang}/soulers/{souler_id}/chapters/generate")
async def generate_chapters(lang: Lang, souler_id: UUID, request: Request):
    lang = str(lang).strip().lower()
    if lang not in SUPPORTED_LANGS:
        return JSONResponse(
            {"error": "Invalid lang, must be one of: en, chs"},
            status_code=400,
        )

    try:
        await asyncio.to_thread(
            get_user_id_from_auth_header,
            request.headers.get("Authorization"),
        )
    except UnauthorizedError:
        return JSONResponse({"error": "Unauthorized"}, status_code=401)
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to validate auth: %s", error_log_payload(error))
        return JSONResponse({"error": error_message(error)}, status_code=400)

    souler_key = str(souler_id)
    try:
        start_result = await asyncio.to_thread(
            start_souler_chapters_generation,
            souler_key,
        )
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to start chapter generation: %s", error_log_payload(error))
        return JSONResponse({"error": error_message(error)}, status_code=400)

    can_start = bool(start_result.get("can_start"))
    status = str(start_result.get("status", "")).strip() or "pending"
    message = str(start_result.get("message", "")).strip()

    if not can_start:
        return JSONResponse(
            {
                "status": status,
                "message": message,
            },
            status_code=200,
        )

    async with _generation_tasks_lock:
        task = _generation_tasks.get(souler_key)
        if task and not task.done():
            return JSONResponse(
                {
                    "status": "processing",
                    "message": "chapter generation is already running",
                },
                status_code=202,
            )

        _generation_tasks[souler_key] = asyncio.create_task(
            _run_generation_job(souler_key, lang)
        )

    return JSONResponse(
        {
            "status": "processing",
            "message": message or "chapter generation started",
        },
        status_code=202,
    )


@router.post("/{lang}/soulers/{souler_id}/chapters/{chapter_id}/start")
async def start_chapter_session(
    lang: Lang,
    souler_id: UUID,
    chapter_id: UUID,
    request: Request,
):
    lang = str(lang).strip().lower()
    if lang not in SUPPORTED_LANGS:
        return JSONResponse(
            {"error": "Invalid lang, must be one of: en, chs"},
            status_code=400,
        )

    try:
        user_id = await asyncio.to_thread(
            get_user_id_from_auth_header,
            request.headers.get("Authorization"),
        )
    except UnauthorizedError:
        return JSONResponse({"error": "Unauthorized"}, status_code=401)
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to validate auth: %s", error_log_payload(error))
        return JSONResponse({"error": error_message(error)}, status_code=400)

    try:
        await asyncio.to_thread(consume_chat_credit, user_id)
    except CreditLimitError as error:
        return JSONResponse(
            {
                "code": error.code,
                "error": str(error),
            },
            status_code=402,
        )
    except Exception as error:  # noqa: BLE001
        logger.error("Failed to consume chat credit: %s", error_log_payload(error))
        return JSONResponse({"error": error_message(error)}, status_code=400)

    created_session_id: str | None = None
    assistant_written = False

    try:
        souler = await asyncio.to_thread(get_souler_by_id, str(souler_id))
        chapter = await asyncio.to_thread(get_chapter_by_id, str(chapter_id))
        if chapter["souler_id"] != str(souler_id):
            raise ValueError("Chapter does not belong to souler")

        created_session_id = await asyncio.to_thread(
            create_session,
            user_id,
            str(souler_id),
            chapter["title"],
            chapter["id"],
        )

        opening_raw = await complete_text(
            _build_chapter_opening_messages(
                souler_name=souler["name"],
                chapter=chapter,
                lang=lang,
            ),
            model=CHAPTER_SESSION_MODEL,
            temperature=settings.CHAT_TEMPERATURE,
        )
        opening_content, options = parse_chapter_combined_response(opening_raw)
        opening_storage_content = opening_raw.strip()
        if not opening_storage_content:
            raise ValueError("Empty chapter opening response")

        assistant_message = await asyncio.to_thread(
            insert_message,
            user_id,
            str(souler_id),
            created_session_id,
            "assistant",
            opening_storage_content,
        )
        assistant_written = True

        try:
            await asyncio.to_thread(
                touch_session,
                user_id,
                created_session_id,
            )
            await asyncio.to_thread(
                create_or_update_resonance,
                user_id,
                str(souler_id),
                created_session_id,
                chapter["title"],
            )
        except Exception as side_effect_error:  # noqa: BLE001
            logger.warning(
                "Chapter session side effect failed: session_id=%s error=%s",
                created_session_id,
                error_log_payload(side_effect_error),
            )

        return JSONResponse(
            {
                "session_id": created_session_id,
                "souler_id": str(souler_id),
                "chapter_id": chapter["id"],
                "title": chapter["title"],
                "assistant_message": {
                    "id": assistant_message["id"],
                    "created_at": assistant_message["created_at"],
                    "content": opening_content,
                },
                "options": options,
            },
            status_code=200,
        )
    except Exception as error:  # noqa: BLE001
        if created_session_id and not assistant_written:
            try:
                await asyncio.to_thread(delete_session, user_id, created_session_id)
            except Exception as cleanup_error:  # noqa: BLE001
                logger.warning(
                    "Failed to cleanup chapter session: session_id=%s error=%s",
                    created_session_id,
                    error_log_payload(cleanup_error),
                )

        await _refund_chat_credit_safely(
            user_id,
            reason="chapter_session_start_failed",
        )
        logger.error("Failed to start chapter session: %s", error_log_payload(error))
        return JSONResponse({"error": error_message(error)}, status_code=400)
