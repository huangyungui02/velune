from __future__ import annotations

from functools import lru_cache

from langgraph.graph import END, START, StateGraph

from app.starsea.checkpoint import checkpoint_manager
from app.starsea.nodes import (
    collect_node,
    divination_node,
    glimmer_node,
    starsea_node,
)
from app.starsea.state import RouterAction, State


@lru_cache(maxsize=1)
def build_graph():
    graph = StateGraph(State)
    graph.add_node("collect", collect_node)
    graph.add_node("divination", divination_node)
    graph.add_node("glimmer", glimmer_node)
    graph.add_node("starsea", starsea_node)

    graph.add_conditional_edges(
        START,
        _route,
        {"collect": "collect", "divination": "divination", "starsea": "starsea"},
    )
    graph.add_edge("starsea", END)
    graph.add_edge("divination", END)
    graph.add_edge("collect", "glimmer")
    graph.add_edge("glimmer", END)

    return graph.compile(checkpointer=checkpoint_manager.get())


def reset_graph() -> None:
    build_graph.cache_clear()


def _route(state: State) -> RouterAction:
    user_input = state["user_input"]
    if user_input["type"] == "trigger" and user_input["content"] == "collect":
        return "collect"
    if user_input["type"] == "divination":
        return "divination"
    return "starsea"
