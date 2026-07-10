from __future__ import annotations

FOLIO_OUTPUT_FORMAT = """
# 输出
## 输出格式
除了输出正文，在末尾还要给出 3 个用户可能做出的回应或选择，用于进一步交互。

格式为：
```
这是一段正文的输出示例。

<options>
<opt>这是第一个选项</opt>
<opt>这是第二个选项</opt>
<opt>这是第三个选项</opt>
</options>
```

## 结束输出
当你觉得可以结束时，则不再输出options，而是：
```
这是一段正文。

<end>
```
""".strip()


def folio_system_prompt(prompt: str, lang: str) -> str:
    from app.core.prompts import apply_prompt_lang

    return apply_prompt_lang(f"{prompt.rstrip()}\n\n{FOLIO_OUTPUT_FORMAT}", lang)
