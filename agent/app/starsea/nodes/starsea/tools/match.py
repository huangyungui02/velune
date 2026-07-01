from __future__ import annotations

import json

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.tools import tool
from pydantic import BaseModel, Field

from app.core.llm import create_chat_model
from app.core.prompts import apply_prompt_lang

MATCH_MODEL = "qwen3.5-flash"
MATCH_TEMPERATURE = 0.45

MATCH_PROMPT = """
# 角色
你是星海内部的思想与共鸣匹配工具。

# 任务
根据当前用户的心境，匹配 3 位最能与用户处境产生共鸣的人物。

# 要求
1. 重点不是讲知识，而是找到“这个人为什么能陪用户走过这一刻”。
2. resonance 要说明这个人物如何映照用户当下。
3. whisper 是这个人物可以留给用户的一句回应。
4. 人物必须是真实存在的，并且属于public domain。
5. 人物名、resonance 和 whisper 使用最终输出语言。
6. 不要因为某个人更出名而选择他，而是选择与用户处境最共鸣的人物。

# 输出
仅输出纯 JSON，不要 Markdown。

JSON 结构：
{
  "matches": [
    {
      "name": "name1",
      "resonance": "resonance1",
      "whisper": "whisper1"
    },
    {
      "name": "name2",
      "resonance": "resonance2",
      "whisper": "whisper2"
    },
    {
      "name": "name3",
      "resonance": "resonance3",
      "whisper": "whisper3"
    }
  ]
}
"""


class ThoughtVoice(BaseModel):
    name: str = Field(description="人物姓名")
    resonance: str = Field(description="不超过 40 字，说明与用户当下的共鸣")
    whisper: str = Field(description="10 到 30 字的回应")


class ThoughtMatch(BaseModel):
    matches: list[ThoughtVoice] = Field(
        min_length=3,
        max_length=3,
        description="三位不同人物的共鸣匹配",
    )


@tool("match_resonances")
def match_resonances(context: str, lang: str) -> str:
    """寻找星海中能够与当前用户处境共鸣的历史人物。"""
    model = create_chat_model(model=MATCH_MODEL, temperature=MATCH_TEMPERATURE)
    structured_model = model.with_structured_output(ThoughtMatch, method="json_mode")
    match = structured_model.invoke(
        [
            SystemMessage(content=apply_prompt_lang(MATCH_PROMPT, lang)),
            HumanMessage(content=context),
        ]
    )
    return json.dumps(match.model_dump(mode="json"), ensure_ascii=False)
