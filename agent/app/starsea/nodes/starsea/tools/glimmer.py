from __future__ import annotations

import json

import tiktoken
from langchain_core.tools import tool

from app.starsea.repositories.glimmers import GlimmerMessage, get_glimmer_messages

TOKEN_LIMIT = 2000
LONG_CONTENT_TOKEN_LENGTH = 50
ENCODING = tiktoken.get_encoding("o200k_base")


def create_get_glimmer_messages_tool(user_id: str, *, lang: str):
    @tool("get_glimmer_messages")
    async def get_glimmer_messages_tool(glimmer_id: str) -> str:
        """查询某个 glimmer 对应的星海聊天 messages 详情。"""
        messages = await get_glimmer_messages(user_id, glimmer_id)
        return json.dumps(
            {
                "glimmer_id": glimmer_id,
                "messages": _compressed_text_archives(messages, lang),
            },
            ensure_ascii=False,
        )

    return get_glimmer_messages_tool


def _compressed_text_archives(
    messages: list[GlimmerMessage],
    lang: str,
) -> list[dict[str, str]]:
    archives = [
        {
            "role": message["role"],
            "content": message["content"],
        }
        for message in messages
        if message["type"] == "text"
    ]

    if _content_tokens(archives) <= TOKEN_LIMIT:
        return archives

    _truncate_middle_until_short(archives, lang, role="assistant")
    if _content_tokens(archives) <= TOKEN_LIMIT:
        return archives

    for archive in archives:
        if archive["role"] == "assistant":
            archive["content"] = _omission(len(archive["content"]), lang)
    if _content_tokens(archives) <= TOKEN_LIMIT:
        return archives

    _truncate_middle_until_short(archives, lang, role="user")
    if _content_tokens(archives) <= TOKEN_LIMIT:
        return archives

    user_index = 0
    for archive in archives:
        if archive["role"] != "user":
            continue
        if user_index % 2 == 1:
            archive["content"] = _omission(len(archive["content"]), lang)
        user_index += 1

    return archives


def _truncate_middle_until_short(
    archives: list[dict[str, str]],
    lang: str,
    *,
    role: str,
) -> None:
    for archive in archives:
        while (
            archive["role"] == role
            and _token_count(archive["content"]) > LONG_CONTENT_TOKEN_LENGTH
        ):
            archive["content"] = _truncate_middle(archive["content"], lang)


def _truncate_middle(content: str, lang: str) -> str:
    if len(content) <= 1:
        return content

    omitted_count = len(content) // 2
    start = (len(content) - omitted_count) // 2
    end = start + omitted_count
    return f"{content[:start]}{_omission(omitted_count, lang)}{content[end:]}"


def _omission(count: int, lang: str) -> str:
    if lang == "zh":
        return f"(此处省略{count}个字符)"
    return f"(omitted {count} characters)"


def _content_tokens(archives: list[dict[str, str]]) -> int:
    return sum(_token_count(archive["content"]) for archive in archives)


def _token_count(content: str) -> int:
    return len(ENCODING.encode(content))
