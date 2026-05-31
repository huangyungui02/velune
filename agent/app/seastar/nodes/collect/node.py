from __future__ import annotations

from typing import TYPE_CHECKING, Any

from langchain_core.messages import AIMessage, HumanMessage, SystemMessage

from app.core.llm import create_chat_model
from app.seastar.messages import format_messages

from .prompt import system_prompt

if TYPE_CHECKING:
    from app.seastar.state import State

COLLECT_MODEL = "qwen3.5-flash"
COLLECT_TEMPERATURE = 0.45


def collect_node(state: State) -> dict[str, Any]:
    lang = _state_lang(state)
    model = create_chat_model(model=COLLECT_MODEL, temperature=COLLECT_TEMPERATURE)
    response = model.invoke(
        [
            SystemMessage(content=system_prompt(lang)),
            HumanMessage(content=_conversation_prompt(format_messages(state["messages"], lang), lang)),
        ]
    )
    content = str(response.content).strip()
    message = AIMessage(content=content)

    return {
        "messages": [message],
        "pending_glimmer": content,
        "display": {
            "type": "collect",
            "content": content,
        },
    }


def _state_lang(state: State) -> str:
    return "zh" if state.get("metadata", {}).get("lang") == "zh" else "en"


def _conversation_prompt(conversation: str, lang: str) -> str:
    if lang == "zh":
        return f"完整对话：\n\n{conversation}"
    return f"Full conversation:\n\n{conversation}"
