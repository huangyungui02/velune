from __future__ import annotations

from typing import TYPE_CHECKING, Any, Literal

from langgraph.graph import END
from langgraph.types import Command, interrupt

if TYPE_CHECKING:
    from app.services.starsea.state import State


def confirm_node(state: State) -> Command[Literal["glimmer", "__end__"]]:
    decision = interrupt(
        {
            "type": "glimmer_confirmation",
            "content": state.get("pending_glimmer") or "",
        }
    )

    if not isinstance(decision, dict) or not decision.get("approved"):
        return Command(goto=END)

    content = str(decision.get("content") or "").strip()
    if not content:
        return Command(goto=END)

    return Command(
        update={"confirmed_glimmer": content},
        goto="glimmer",
    )
