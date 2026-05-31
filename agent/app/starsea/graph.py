from __future__ import annotations

from functools import lru_cache

from langgraph.graph import END, START, StateGraph

from app.starsea.checkpoint import get_starsea_checkpointer
from app.starsea.nodes import (
    collect_node,
    glimmer_node,
    starsea_node,
)
from app.starsea.state import RouterAction, State


@lru_cache(maxsize=1)
def build_graph():
    graph = StateGraph(State)
    graph.add_node("collect", collect_node)
    graph.add_node("glimmer", glimmer_node)
    graph.add_node("starsea", starsea_node)

    graph.add_conditional_edges(START, _route, {"collect": "collect", "starsea": "starsea"})
    graph.add_edge("starsea", END)
    graph.add_edge("collect", "glimmer")
    graph.add_edge("glimmer", END)

    return graph.compile(checkpointer=get_starsea_checkpointer())


def reset_graph() -> None:
    build_graph.cache_clear()


def _route(state: State) -> RouterAction:
    return "collect" if state.get("metadata", {}).get("intent") == "collect" else "starsea"
