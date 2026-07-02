from __future__ import annotations

from datetime import datetime
from typing import Any
from zoneinfo import ZoneInfo

from lunar_python import Solar

TRIGRAM_SYMBOLS = {
    ("yang", "yang", "yang"): "天",
    ("yin", "yin", "yin"): "地",
    ("yang", "yin", "yin"): "雷",
    ("yin", "yang", "yang"): "风",
    ("yin", "yang", "yin"): "水",
    ("yang", "yin", "yang"): "火",
    ("yin", "yin", "yang"): "山",
    ("yang", "yang", "yin"): "泽",
}

HEXAGRAM_NAMES = {
    "天天": "乾为天",
    "地地": "坤为地",
    "水雷": "水雷屯",
    "山水": "山水蒙",
    "水天": "水天需",
    "天水": "天水讼",
    "地水": "地水师",
    "水地": "水地比",
    "风天": "风天小畜",
    "天泽": "天泽履",
    "地天": "地天泰",
    "天地": "天地否",
    "天火": "天火同人",
    "火天": "火天大有",
    "地山": "地山谦",
    "雷地": "雷地豫",
    "泽雷": "泽雷随",
    "山风": "山风蛊",
    "地泽": "地泽临",
    "风地": "风地观",
    "火雷": "火雷噬嗑",
    "山火": "山火贲",
    "山地": "山地剥",
    "地雷": "地雷复",
    "天雷": "天雷无妄",
    "山天": "山天大畜",
    "山雷": "山雷颐",
    "泽风": "泽风大过",
    "水水": "坎为水",
    "火火": "离为火",
    "泽山": "泽山咸",
    "雷风": "雷风恒",
    "天山": "天山遁",
    "雷天": "雷天大壮",
    "火地": "火地晋",
    "地火": "地火明夷",
    "风火": "风火家人",
    "火泽": "火泽睽",
    "水山": "水山蹇",
    "雷水": "雷水解",
    "山泽": "山泽损",
    "风雷": "风雷益",
    "泽天": "泽天夬",
    "天风": "天风姤",
    "泽地": "泽地萃",
    "地风": "地风升",
    "泽水": "泽水困",
    "水风": "水风井",
    "泽火": "泽火革",
    "火风": "火风鼎",
    "雷雷": "震为雷",
    "山山": "艮为山",
    "风山": "风山渐",
    "雷泽": "雷泽归妹",
    "雷火": "雷火丰",
    "火山": "火山旅",
    "风风": "巽为风",
    "泽泽": "兑为泽",
    "风水": "风水涣",
    "水泽": "水泽节",
    "风泽": "风泽中孚",
    "雷山": "雷山小过",
    "水火": "水火既济",
    "火水": "火水未济",
}


def build_divination_user_prompt(
    *,
    divination: dict[str, Any],
    timezone: str | None,
    lang: str,
) -> str:
    casted_lines = divination["casted_lines"]
    date = datetime.fromisoformat(divination["date"])
    question = divination["question"]
    local_date = _local_datetime(date, timezone)
    ganzhi = _ganzhi(local_date)

    primary = _hexagram(casted_lines, changed=False)
    changed = _hexagram(casted_lines, changed=True)
    moving = _moving(casted_lines)

    prompt = "\n".join(
        [
            "# 六爻起卦上下文",
            f"主卦：{primary}",
            f"变卦：{changed}",
            f"起卦时间：{ganzhi}",
            f"动爻：{moving}",
            "",
            "# 问题",
            question,
        ]
    )
    return prompt


def _local_datetime(date: datetime, timezone: str | None) -> datetime:
    if date.tzinfo is None:
        date = date.replace(tzinfo=ZoneInfo(timezone or "UTC"))
    if timezone is None:
        return date
    return date.astimezone(ZoneInfo(timezone))


def _ganzhi(date: datetime) -> str:
    solar = Solar.fromYmdHms(
        date.year,
        date.month,
        date.day,
        date.hour,
        date.minute,
        date.second,
    )
    lunar = solar.getLunar()
    # Exact day uses 23:00 as the day-pillar boundary.
    return " ".join(
        [
            f"{lunar.getYearInGanZhiByLiChun()}年",
            f"{lunar.getMonthInGanZhiExact()}月",
            f"{lunar.getDayInGanZhiExact()}日",
            f"{lunar.getTimeInGanZhi()}时",
        ]
    )


def _hexagram(casted_lines: list[int], *, changed: bool) -> str:
    line_types = [_line_type(line, changed=changed) for line in casted_lines]
    key = _trigram_symbol(line_types[3:]) + _trigram_symbol(line_types[:3])
    return HEXAGRAM_NAMES.get(key, "未知卦")


def _line_type(line: int, *, changed: bool) -> str:
    if line == 0:
        return "yang"
    if line == 1:
        return "yin"
    if line == 2:
        return "yin" if changed else "yang"
    return "yang" if changed else "yin"


def _trigram_symbol(lines: list[str]) -> str:
    return TRIGRAM_SYMBOLS[tuple(lines)]


def _moving(casted_lines: list[int]) -> str:
    lines = [
        _moving_line_name(index, line)
        for index, line in enumerate(casted_lines, start=1)
        if line in {2, 3}
    ]
    if not lines:
        return "无，以本卦为主"
    return "、".join(lines)


def _moving_line_name(index: int, line: int) -> str:
    position = ["初", "二", "三", "四", "五", "上"][index - 1]
    polarity = "九" if line == 2 else "六"
    if index == 1:
        return f"初{polarity}"
    if index == 6:
        return f"上{polarity}"
    return f"{polarity}{position}"
