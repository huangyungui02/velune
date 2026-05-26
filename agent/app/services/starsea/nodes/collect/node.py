from __future__ import annotations

from typing import TYPE_CHECKING, Any

from langchain_core.messages import AIMessage, HumanMessage, SystemMessage

from app.services.starsea.llm import create_chat_model
from app.services.starsea.messages import format_messages

from .prompt import SYSTEM_PROMPT

if TYPE_CHECKING:
    from app.services.starsea.state import State

COLLECT_MODEL = "qwen3.5-flash"
COLLECT_TEMPERATURE = 0.45


def collect_node(state: State) -> dict[str, Any]:
    model = create_chat_model(model=COLLECT_MODEL, temperature=COLLECT_TEMPERATURE)
    response = model.invoke(
        [
            SystemMessage(content=SYSTEM_PROMPT),
            HumanMessage(content=f"完整对话：\n\n{format_messages(state['messages'])}"),
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
