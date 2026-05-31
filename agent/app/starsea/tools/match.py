from __future__ import annotations

import json

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.tools import tool
from pydantic import AliasChoices, BaseModel, Field

from app.core.llm import create_chat_model

MATCH_MODEL = "qwen3.5-flash"
MATCH_TEMPERATURE = 0.45

MATCH_PROMPTS = {
    "zh": """
# 角色
你是星海内部的思想与灵魂匹配工具。

# 任务
根据当前对话，匹配 3 位最能与用户处境产生共鸣的人物。

# 要求
1. 重点不是讲知识，而是找到“这个人为什么能陪用户走过这一刻”。
2. resonance 要说明这个人物如何映照用户当下。
3. whisper 是这个人物可以留给用户的一句回应。
4. 人物必须是真实存在的，并且属于public domain。
5. 人物名必须是简体中文。

# 输出
仅输出纯 JSON，不要 Markdown。

JSON 结构：
{
  "voices": [
    {
      "name": "人物姓名",
      "resonance": "与用户当下的共鸣",
      "whisper": "一句低声回应"
    }
  ]
}
""",
    "en": """
# Role
You are StarSea's internal tool for matching thoughts and souls.

# Task
Based on the current conversation, match 3 public-domain historical figures who can resonate most deeply with the user's situation.

# Requirements
1. The goal is not to teach facts, but to find why this person can accompany the user through this moment.
2. resonance should explain how the figure mirrors the user's present state.
3. whisper is one short response this figure might leave for the user.
4. Figures must be real people and in the public domain.
5. Figure names must be in English.

# Output
Output pure JSON only. No Markdown.

JSON structure:
{
  "voices": [
    {
      "name": "Person name",
      "resonance": "How this person resonates with the user's present state",
      "whisper": "A short whispered response"
    }
  ]
}
""",
}


class ThoughtVoice(BaseModel):
    name: str = Field(description="人物姓名")
    resonance: str = Field(description="不超过 40 字，说明与用户当下的共鸣")
    whisper: str = Field(description="10 到 30 字的回应")


class ThoughtMatch(BaseModel):
    voices: list[ThoughtVoice] = Field(
        min_length=3,
        max_length=3,
        validation_alias=AliasChoices("voices", "matches"),
        description="三位不同人物的共鸣匹配",
    )


@tool
def match_thought_voices(conversation: str, lang: str = "zh") -> str:
    """寻找星海中能够与当前用户处境共鸣的灵魂。"""
    normalized_lang = "zh" if lang == "zh" else "en"
    model = create_chat_model(model=MATCH_MODEL, temperature=MATCH_TEMPERATURE)
    structured_model = model.with_structured_output(ThoughtMatch, method="json_mode")
    match = structured_model.invoke(
        [
            SystemMessage(content=MATCH_PROMPTS[normalized_lang]),
            HumanMessage(content=_conversation_prompt(conversation, normalized_lang)),
        ]
    )

    return json.dumps(match.model_dump(mode="json"), ensure_ascii=False)


def _conversation_prompt(conversation: str, lang: str) -> str:
    if lang == "zh":
        return f"对话内容：\n\n{conversation}"
    return f"Conversation:\n\n{conversation}"
