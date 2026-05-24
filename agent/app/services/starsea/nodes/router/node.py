from __future__ import annotations

from typing import TYPE_CHECKING, Literal

from langchain_core.messages import HumanMessage, SystemMessage
from langgraph.types import Command

from app.services.starsea.llm import create_chat_model

from .model import RouterDecision
from .prompt import SYSTEM_PROMPT

if TYPE_CHECKING:
    from app.services.starsea.state import State

ROUTER_MODEL = "qwen3.5-flash"
ROUTER_TEMPERATURE = 0


def router_node(state: State) -> Command[Literal["starsea", "collect"]]:
    model = create_chat_model(model=ROUTER_MODEL, temperature=ROUTER_TEMPERATURE)
    structured_model = model.with_structured_output(RouterDecision, method="json_mode")
    decision = structured_model.invoke(
        [
            SystemMessage(content=SYSTEM_PROMPT),
            HumanMessage(content=f"用户最新一句话：{_latest_user_message(state)}"),
        ]
    )

    return Command(goto=decision.action)


def _latest_user_message(state: State) -> str:
    for message in reversed(state["messages"]):
        if isinstance(message, HumanMessage):
            return str(message.content).strip()

    return ""
