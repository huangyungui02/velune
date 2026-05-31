from __future__ import annotations

from functools import lru_cache

from langgraph.graph import END, START, StateGraph

from app.seastar.checkpoint import get_starsea_checkpointer
from app.seastar.nodes import (
    collect_node,
    confirm_node,
    glimmer_node,
    router_node,
    starsea_node,
)
from app.seastar.state import State


@lru_cache(maxsize=1)
def build_graph():
    graph = StateGraph(State)
    graph.add_node("router", router_node)
    graph.add_node("collect", collect_node)
    graph.add_node("confirm", confirm_node)
    graph.add_node("glimmer", glimmer_node)
    graph.add_node("starsea", starsea_node)

    graph.add_edge(START, "router")
    graph.add_edge("starsea", END)
    graph.add_edge("collect", "confirm")
    graph.add_edge("glimmer", END)

    return graph.compile(checkpointer=get_starsea_checkpointer())


def reset_graph() -> None:
    build_graph.cache_clear()
