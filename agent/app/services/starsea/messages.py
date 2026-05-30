from __future__ import annotations

from typing import Any

from langchain_core.messages import AIMessage, AnyMessage, HumanMessage, ToolMessage


def format_messages(messages: list[AnyMessage], lang: str = "zh") -> str:
    lines: list[str] = []
    for message in messages:
        content = _content_to_text(message.content)
        if not content:
            continue

        lines.append(f"{_role_name(message, lang)}：{content}")

    return "\n\n".join(lines)


def _role_name(message: AnyMessage, lang: str) -> str:
    if isinstance(message, HumanMessage):
        return "用户" if lang == "zh" else "User"
    if isinstance(message, AIMessage):
        return "AI"
    if isinstance(message, ToolMessage):
        return "工具" if lang == "zh" else "Tool"

    return message.type


def _content_to_text(content: Any) -> str:
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, str):
                parts.append(item)
            elif isinstance(item, dict) and isinstance(item.get("text"), str):
                parts.append(item["text"])

        return "\n".join(parts).strip()

    return str(content).strip()
