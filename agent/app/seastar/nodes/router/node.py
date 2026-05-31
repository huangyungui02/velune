from __future__ import annotations

from typing import TYPE_CHECKING, Literal

from langchain_core.messages import HumanMessage, SystemMessage
from langgraph.types import Command

from app.core.llm import create_chat_model

from .model import RouterDecision
from .prompt import system_prompt

if TYPE_CHECKING:
    from app.seastar.state import State

ROUTER_MODEL = "qwen3.5-flash"
ROUTER_TEMPERATURE = 0


def router_node(state: State) -> Command[Literal["starsea", "collect"]]:
    if state.get("metadata", {}).get("intent") == "collect":
        return Command(goto="collect")

    lang = _state_lang(state)
    model = create_chat_model(model=ROUTER_MODEL, temperature=ROUTER_TEMPERATURE)
    structured_model = model.with_structured_output(RouterDecision, method="json_mode")
    decision = structured_model.invoke(
        [
            SystemMessage(content=system_prompt(lang)),
            HumanMessage(content=_latest_message_prompt(_latest_user_message(state), lang)),
        ]
    )

    return Command(goto=decision.action)


def _latest_user_message(state: State) -> str:
    for message in reversed(state["messages"]):
        if isinstance(message, HumanMessage):
            return str(message.content).strip()

    return ""


def _state_lang(state: State) -> str:
    return "zh" if state.get("metadata", {}).get("lang") == "zh" else "en"


def _latest_message_prompt(message: str, lang: str) -> str:
    if lang == "zh":
        return f"用户最新一句话：{message}"
    return f"User's latest message: {message}"
