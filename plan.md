# Souler 多语言身份实施记录

## 目标

- `soulers` 只表示同一个人物身份，`wiki_id` 使用 Wikidata id 并全局唯一。
- `souler_profile` 按 `souler_id + lang` 保存语言相关的 `name` 和 `introduction`。
- `chapters` 按 `souler_id + lang + seq` 唯一。
- `souler_aliases` 保持现有字段，`alias` 全局唯一，不按语言区分。
- `discover_sections` 所有语言共用同一个 section，标题和副标题放到 `discover_section_profile`。
- 头像路径迁移到 `soulers.avatar`，移除 `souler_avatars`。

## 解析流程

1. Admin 或星海传入 `name + lang`。
2. 先查全局 alias，命中则把本次输入名补进 alias，并直接 complete。
3. 未命中时 canonicalize，再查 canonical alias，命中也先补 alias 再 complete。
4. 通过 Wikipedia/Wikidata 获取 `wiki_id`。
5. 如果 `wiki_id` 已存在 souler，先补 alias，再 complete。
6. 如果不存在，生成 `supported_langs = ["zh", "en"]` 两套 profile、keywords、chapters。
7. 在同一个 transaction 内插入 `soulers`、aliases、profiles、keywords、chapters，并 complete request。

## Admin

- 新建人物走 Agent API 的 `resolve_or_enqueue_souler`。
- 重复命中直接进入详情页。
- 新人物创建为 pending 时在页面轮询 resolution 状态，完成后进入详情页。
- 编辑页顶部提供中文/英文 tab，分别保存 profile、keywords、chapters。
- `wiki_id`、审核状态、头像和 aliases 属于身份区，aliases 可编辑。
