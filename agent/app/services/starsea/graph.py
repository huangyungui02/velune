from __future__ import annotations

from functools import lru_cache

from langgraph.graph import END, START, StateGraph

from app.services.starsea.checkpoint import get_starsea_checkpointer
from app.services.starsea.nodes import collect_node, router_node, starsea_node
from app.services.starsea.state import State


@lru_cache(maxsize=1)
def build_graph():
    graph = StateGraph(State)
    graph.add_node("router", router_node)
    graph.add_node("collect", collect_node)
    graph.add_node("starsea", starsea_node)

    graph.add_edge(START, "router")
    graph.add_edge("starsea", END)
    graph.add_edge("collect", END)

    return graph.compile(checkpointer=get_starsea_checkpointer())


def reset_graph() -> None:
    build_graph.cache_clear()
