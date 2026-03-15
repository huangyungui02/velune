from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Any, Literal

from app.config import get_settings
from app.errors import CreditLimitError, CreditState
from app.llm import complete_json, complete_text
from app.supabase_repo import (
    append_souler_alias,
    consume_user_credit,
    create_echo,
    create_or_update_resonance,
    create_session,
    create_souler,
    get_souler_by_alias,
    insert_session_message,
    update_souler,
)

Lang = Literal["chs", "en"]

settings = get_settings()

ALIASES_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "aliases": {
            "type": "array",
            "items": {"type": "string"},
        }
    },
    "required": ["aliases"],
    "additionalProperties": False,
}


alias_prompt: dict[Lang, str] = {
    "en": (
        "You are an expert in entity resolution and name normalization. "
        "Generate a comprehensive list of practical aliases for a given person's name to improve search and matching accuracy.\n"
        "Rules:\n"
        "1. Canonical Full Name: Include the complete official name (e.g., \"Einstein\" -> \"Albert Einstein\").\n"
        "2. Pseudonyms & Stage Names: Include known pen names, stage names, or widely recognized monikers.\n"
        "3. Titles & Honorifics: Include forms with commonly associated titles if they are widely used for identification.\n"
        "4. Variant Spellings & Transliterations: Include common alternative spellings or anglicized forms.\n"
        "5. Diminutives & Nicknames: Include widely accepted short forms.\n"
        "6. Language: All aliases must be in English.\n"
        "7. Output: Return ONLY a JSON object with an \"aliases\" array containing unique, concise, realistic string values."
    ),
    "chs": (
        "你是实体解析和名称标准化的专家。请为给定的人物名称生成全面且实用的别名列表，以提高搜索和匹配的准确性。\n"
        "规则：\n"
        "1. 完整姓名：包含官方的完整姓名。\n"
        "2. 笔名与艺名：包含众所周知的笔名、艺名或化名。\n"
        "3. 字号与尊称：对于历史人物，包含其字、号、谥号或广泛使用的尊称。\n"
        "4. 异译与拼写变体：包含常见的不同音译或写法。\n"
        "5. 简称与昵称：包含被广泛接受的缩写或简称。\n"
        "6. 语言：所有别名必须使用中文。\n"
        "7. 输出：仅返回包含 \"aliases\" 字符串数组的 JSON 对象。别名应简洁、真实、去重。"
    ),
}

match_prompt: dict[Lang, Callable[[int], str]] = {
    "en": lambda num: (
        f"Analyze the user's journal entry and find exactly {num} specific figures who deeply resonate with the user. "
        "Return JSON as {\"data\":[{\"souler\":\"...\",\"content\":\"...\"}]}. "
        "souler must be exact names of specific well-known people and all souler values must be unique. "
        "The entire output must be in English."
    ),
    "chs": lambda num: (
        f"深入分析用户的日记，找到恰好 {num} 位与其心境深度共鸣的具体人物。"
        "返回 JSON：{\"data\":[{\"souler\":\"...\",\"content\":\"...\"}]}. "
        "souler 必须是具体知名人物姓名且唯一，content 是深刻且有同理心的回应。输出仅使用中文。"
    ),
}

profile_prompt: dict[Lang, str] = {
    "en": "Write an introduction for the given souler.",
    "chs": "为给定灵魂写一段人物简介。",
}

role_prompt: dict[Lang, str] = {
    "en": "You generate role prompts. For the given person, write a concise character prompt for an LLM to simulate that person. The prompt must start with 'You are'.",
    "chs": "你是角色提示词生成器。为给定人物编写一段简洁的角色提示词，供大语言模型模拟该人物使用。提示词必须以\"你是\"开头。",
}

answer_prompt: dict[Lang, Callable[[str], str]] = {
    "en": lambda prompt: (
        "# Role\n"
        f"{prompt}\n\n"
        "# Task\n"
        "Respond to the user's soul fragment in this persona.\n\n"
        "# Output\n"
        "Return only the response content.\n"
        "The response must be in English only."
    ),
    "chs": lambda prompt: (
        "# 角色\n"
        f"{prompt}\n\n"
        "# 任务\n"
        "以此角色身份回应用户的灵魂碎片。\n\n"
        "# 输出\n"
        "仅返回回复内容。\n"
        "回复内容必须只使用中文。"
    ),
}

session_title_prompt: dict[Lang, str] = {
    "en": "Create a concise chat title from the user's glimmer and souler echo. Keep it under 8 words, no punctuation, no quotes, and return only the title text. Title must be in English only.",
    "chs": "根据用户 glimmer 和 souler echo 生成一个简洁会话标题。限制 8 个字以内，不要标点，不要引号，只返回标题文本。标题必须只使用中文。",
}


@dataclass
class GraphResult:
    completed: bool
    credit_state: CreditState | None


def _match_schema(num: int) -> dict[str, Any]:
    return {
        "type": "object",
        "properties": {
            "data": {
                "type": "array",
                "minItems": num,
                "maxItems": num,
                "items": {
                    "type": "object",
                    "properties": {
                        "souler": {"type": "string"},
                        "content": {"type": "string"},
                    },
                    "required": ["souler", "content"],
                    "additionalProperties": False,
                },
            }
        },
        "required": ["data"],
        "additionalProperties": False,
    }


def _normalize_aliases(name: str, aliases: list[str]) -> list[str]:
    seen: set[str] = set()
    normalized: list[str] = []

    def push(candidate: str) -> None:
        cleaned = candidate.strip()
        if not cleaned:
            return
        key = cleaned.lower()
        if key in seen:
            return
        seen.add(key)
        normalized.append(cleaned)

    push(name)
    for alias in aliases:
        push(alias)

    return normalized


async def generate_souler_aliases(name: str, lang: Lang) -> list[str]:
    cleaned_name = name.strip()
    if not cleaned_name:
        return [name]

    payload = await complete_json(
        [
            {"role": "system", "content": alias_prompt[lang]},
            {"role": "user", "content": f"Name: {cleaned_name}"},
        ],
        schema_name="souler_aliases",
        schema=ALIASES_SCHEMA,
        temperature=settings.MODEL_S_TEMPERATURE,
    )
    aliases_raw = payload.get("aliases") if isinstance(payload, dict) else None
    aliases = [str(item) for item in aliases_raw or [] if str(item).strip()]
    return _normalize_aliases(cleaned_name, aliases)


async def match_soulers(content: str, num: int, lang: Lang) -> list[dict[str, str]]:
    payload = await complete_json(
        [
            {"role": "system", "content": match_prompt[lang](num)},
            {"role": "user", "content": content},
        ],
        schema_name="matched_soulers",
        schema=_match_schema(num),
        temperature=settings.MODEL_L_TEMPERATURE,
    )
    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, list):
        raise ValueError("Invalid souler match response")

    results: list[dict[str, str]] = []
    seen: set[str] = set()
    for item in data:
        if not isinstance(item, dict):
            continue
        souler = str(item.get("souler", "")).strip()
        response_content = str(item.get("content", "")).strip()
        if not souler:
            continue
        key = souler.lower()
        if key in seen:
            continue
        seen.add(key)
        results.append(
            {
                "souler": souler,
                "content": response_content,
            }
        )

    if len(results) != num:
        raise ValueError(f"Expected {num} matched soulers, got {len(results)}")

    return results


async def souler_profile(souler: str, lang: Lang) -> str:
    return await complete_text(
        [
            {"role": "system", "content": profile_prompt[lang]},
            {"role": "user", "content": souler},
        ],
        temperature=settings.MODEL_S_TEMPERATURE,
    )


async def souler_prompt(souler: str, lang: Lang) -> str:
    return await complete_text(
        [
            {"role": "system", "content": role_prompt[lang]},
            {"role": "user", "content": souler},
        ],
        temperature=settings.MODEL_S_TEMPERATURE,
    )


async def souler_answer(content: str, prompt: str, lang: Lang) -> str:
    return await complete_text(
        [
            {"role": "system", "content": answer_prompt[lang](prompt)},
            {"role": "user", "content": content},
        ],
        temperature=settings.MODEL_S_TEMPERATURE,
    )


def _sanitize_title(raw: str, lang: Lang) -> str:
    trimmed = raw.strip().strip('"\'`')
    if not trimmed:
        return "未命名会话" if lang == "chs" else "Untitled Session"

    if lang == "chs":
        return trimmed[:16]

    return " ".join(trimmed.split()[:8])


async def session_title(glimmer: str, echo: str, lang: Lang) -> str:
    raw = await complete_text(
        [
            {"role": "system", "content": session_title_prompt[lang]},
            {"role": "user", "content": f"Glimmer:\n{glimmer}\n\nEcho:\n{echo}"},
        ],
        temperature=settings.MODEL_S_TEMPERATURE,
    )
    return _sanitize_title(raw, lang)


def _reason_to_message(reason: Any) -> str:
    if isinstance(reason, Exception) and str(reason).strip():
        return str(reason)
    if isinstance(reason, str) and reason.strip():
        return reason
    if isinstance(reason, dict):
        for key in ("message", "error", "details", "hint"):
            value = reason.get(key)
            if isinstance(value, str) and value.strip():
                return value
    return "Unknown failure"


async def invoke_echo_graph(
    *,
    user_id: str,
    glimmer_id: str,
    glimmer_content: str,
    num: int,
    lang: Lang,
    on_echo: Callable[[dict[str, Any]], Awaitable[None] | None] | None = None,
) -> GraphResult:
    soulers = await match_soulers(glimmer_content, num, lang)

    async def process_item(item: dict[str, str]) -> CreditState:
        matched_name = item.get("souler", "").strip()
        if not matched_name:
            raise ValueError("Matched souler name cannot be empty")

        souler_data = get_souler_by_alias(matched_name)
        if not souler_data:
            aliases = await generate_souler_aliases(matched_name, lang)
            souler_data = create_souler(matched_name, aliases)
        else:
            souler_data = append_souler_alias(str(souler_data["id"]), matched_name)

        bio = souler_data.get("bio")
        if not isinstance(bio, str) or not bio.strip():
            generated_bio = await souler_profile(str(souler_data["name"]), lang)
            souler_data["bio"] = generated_bio
            update_souler(str(souler_data["id"]), {"bio": generated_bio})

        prompt = souler_data.get("prompt")
        if not isinstance(prompt, str) or not prompt.strip():
            generated_prompt = await souler_prompt(str(souler_data["name"]), lang)
            souler_data["prompt"] = generated_prompt
            update_souler(str(souler_data["id"]), {"prompt": generated_prompt})

        credit_state = consume_user_credit(user_id)
        answer = await souler_answer(
            glimmer_content,
            str(souler_data["prompt"]),
            lang,
        )
        title = await session_title(glimmer_content, answer, lang)

        session_id = create_session(
            user_id,
            str(souler_data["id"]),
            title,
        )

        insert_session_message(
            user_id,
            str(souler_data["id"]),
            session_id,
            "user",
            glimmer_content,
        )
        insert_session_message(
            user_id,
            str(souler_data["id"]),
            session_id,
            "assistant",
            answer,
        )

        echo = create_echo(
            glimmer_id,
            str(souler_data["id"]),
            answer,
            session_id,
        )
        echo["souler_name"] = str(souler_data.get("name", "")).strip()
        create_or_update_resonance(user_id, str(souler_data["id"]))

        if on_echo:
            maybe_awaitable = on_echo(echo)
            if asyncio.iscoroutine(maybe_awaitable):
                await maybe_awaitable

        return credit_state

    results = await asyncio.gather(
        *(process_item(item) for item in soulers),
        return_exceptions=True,
    )

    errors: list[str] = []
    first_credit_limit_error: CreditLimitError | None = None
    final_credit_state: CreditState | None = None
    completed = True

    for result in results:
        if isinstance(result, Exception):
            errors.append(_reason_to_message(result))
            if not first_credit_limit_error and isinstance(result, CreditLimitError):
                first_credit_limit_error = result
            continue

        if not final_credit_state:
            final_credit_state = result
            continue

        final_credit_state = CreditState(
            plan=result.plan,
            monthly_limit=result.monthly_limit,
            credits_remaining=min(
                final_credit_state.credits_remaining,
                result.credits_remaining,
            ),
        )

    if len(errors) == num:
        if first_credit_limit_error:
            raise first_credit_limit_error
        raise RuntimeError(f"Errors when creating echoes: {' | '.join(errors)}")

    if errors:
        completed = False

    return GraphResult(
        completed=completed,
        credit_state=final_credit_state,
    )
