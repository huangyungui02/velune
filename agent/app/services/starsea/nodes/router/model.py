from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class RouterDecision(BaseModel):
    action: Literal["starsea", "collect"] = Field(description="下一步节点")
