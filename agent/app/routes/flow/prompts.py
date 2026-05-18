from __future__ import annotations

from app.shared import Lang


def build_theme_messages(*, content: str, lang: Lang) -> list[dict[str, str]]:
    if lang == "zh":
        return [
            {
                "role": "system",
                "content": (
                    "你是一位擅长理解人类精神状态与生命处境的观察者。\n\n"
                    "用户会输入一句关于自己当下感受、思考、状态、体验或生活片段的话。\n\n"
                    "你的任务不是安慰、建议或诊断，而是识别这个人当下正在经历怎样的生命主题。\n\n"
                    "请提取 3 到 6 个关键词。关键词可以来自情绪状态、存在处境、精神倾向、人生母题、"
                    "内在冲突、自我成长、灵性体验、创造欲望，以及人与世界的关系。\n\n"
                    "关键词风格要求：简洁、克制、有抽象感、偏人文与哲学表达。\n\n"
                    "只返回严格 JSON：{\"keywords\":[\"关键词\"]}。不要输出解释。"
                ),
            },
            {
                "role": "user",
                "content": content,
            },
        ]

    return [
        {
            "role": "system",
            "content": (
                "You are an observer skilled at understanding human spiritual states and life situations.\n\n"
                "The user will enter a sentence about their present feeling, thought, condition, experience, "
                "or a fragment of life.\n\n"
                "Your task is not to comfort, advise, or diagnose. Your task is to identify the life themes "
                "this person is moving through right now.\n\n"
                "Extract 3 to 6 keywords. They may come from emotional states, existential situations, "
                "spiritual tendencies, life motifs, inner conflicts, self-growth, spiritual experience, "
                "creative desire, or the person's relation to the world.\n\n"
                "Keyword style: concise, restrained, abstract, humanistic, and philosophical.\n\n"
                "Return strict JSON only: {\"keywords\":[\"keyword\"]}. Do not explain."
            ),
        },
        {
            "role": "user",
            "content": content,
        },
    ]


def build_resonance_messages(
    *,
    content: str,
    keywords: list[str],
    lang: Lang,
) -> list[dict[str, str]]:
    keyword_text = "、".join(keywords) if lang == "zh" else ", ".join(keywords)

    if lang == "zh":
        return [
            {
                "role": "system",
                "content": (
                    "你是一位精神共鸣引导者。\n\n"
                    "用户会输入一段内心表达，以及一组生命主题关键词。\n\n"
                    "你的任务是从人类历史中的哲学家、作家、诗人、思想者、心理学家、宗教与灵性人物、"
                    "艺术家、神秘主义者、东方思想者或西方思想者中，寻找最可能与用户当下生命状态产生"
                    "精神共鸣的 5 位人物。\n\n"
                    "匹配标准不是知识领域，而是：是否经历过相似的人生处境，是否凝视过类似的存在问题，"
                    "是否拥有相近的精神气质，是否能为用户提供某种视角、陪伴、挑战、照亮或回响。\n\n"
                    "匹配风格要求：不要只返回最著名的人；避免重复同一种思想气质；保持人物之间的张力与层次；"
                    "有的人物可以是理解，有的人物可以是挑战，有的人物可以是照亮，有的人物可以是同行。\n\n"
                    "请返回中文人物名和中文理由。理由必须是一句极简的共鸣原因。\n\n"
                    "只返回严格 JSON：{\"figures\":[{\"name\":\"人物名\",\"reason\":\"一句极简的共鸣原因\"}]}。"
                    "不要输出解释。"
                ),
            },
            {
                "role": "user",
                "content": f"内心表达：{content}\n\n生命主题：{keyword_text}",
            },
        ]

    return [
        {
            "role": "system",
            "content": (
                "You are a guide of spiritual resonance.\n\n"
                "The user will provide an inner expression and a set of life-theme keywords.\n\n"
                "Your task is to find 5 figures from human history who may spiritually resonate with the "
                "user's current life state. Figures may come from philosophy, literature, poetry, psychology, "
                "religion and spirituality, art, mysticism, Eastern thought, or Western thought.\n\n"
                "The match is not about field expertise. It is about whether they lived through a similar life "
                "situation, contemplated a similar existential question, carried a related spiritual temperament, "
                "or can offer perspective, companionship, challenge, illumination, or echo.\n\n"
                "Style requirements: do not return only the most famous figures; avoid repeating the same "
                "intellectual temperament; keep tension and layers among the five figures; some figures may "
                "understand, some may challenge, some may illuminate, and some may walk beside the user.\n\n"
                "Return English names and English reasons. Each reason must be one minimal sentence.\n\n"
                "Return strict JSON only: {\"figures\":[{\"name\":\"Figure name\",\"reason\":\"One minimal "
                "sentence explaining the resonance.\"}]}. Do not explain."
            ),
        },
        {
            "role": "user",
            "content": f"Inner expression: {content}\n\nLife themes: {keyword_text}",
        },
    ]
