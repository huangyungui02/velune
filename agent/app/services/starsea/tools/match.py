from __future__ import annotations

import json

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.tools import tool
from pydantic import AliasChoices, BaseModel, Field

from app.services.starsea.llm import create_chat_model

MATCH_MODEL = "qwen3.5-flash"
MATCH_TEMPERATURE = 0.45

MATCH_PROMPT = """
# 角色
你是星海内部的思想与灵魂匹配工具。

# 任务
根据当前对话，匹配 3 位最能与用户处境产生共鸣的人物。

# 要求
1. 每个人物都要对应一种不同的内在主题，例如孤独、失去、重生、自由、
自我评判、身份认同、意义、身体感受等等。
2. 重点不是讲知识，而是找到“这个人为什么能陪用户走过这一刻”。
3. resonance 要说明这个人物如何映照用户当下。
4. whisper 是这个人物可以留给用户的一句低声回应，必须平实、具体、有穿透力，不要引用名言。

# 输出
仅输出纯 JSON，不要 Markdown。

JSON 结构：
{
  "voices": [
    {
      "name": "人物姓名",
      "theme": "内在主题",
      "resonance": "与用户当下的共鸣",
      "whisper": "一句低声回应"
    }
  ]
}
"""


class ThoughtVoice(BaseModel):
    name: str = Field(description="人物姓名")
    theme: str = Field(description="对应的内在主题")
    resonance: str = Field(description="不超过 40 字，说明与用户当下的共鸣")
    whisper: str = Field(description="10 到 30 字的低声回应")


class ThoughtMatch(BaseModel):
    voices: list[ThoughtVoice] = Field(
        min_length=3,
        max_length=3,
        validation_alias=AliasChoices("voices", "matches"),
        description="三位不同人物的共鸣匹配",
    )


@tool
def match_thought_voices(conversation: str) -> str:
    """匹配能与当前对话共鸣的灵魂。除非用户要求，否则不要调用此工具。"""
    model = create_chat_model(model=MATCH_MODEL, temperature=MATCH_TEMPERATURE)
    structured_model = model.with_structured_output(ThoughtMatch, method="json_mode")
    match = structured_model.invoke(
        [
            SystemMessage(content=MATCH_PROMPT),
            HumanMessage(content=f"对话内容：\n\n{conversation}"),
        ]
    )

    return json.dumps(match.model_dump(mode="json"), ensure_ascii=False)
