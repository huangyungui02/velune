# 星海 Glimmer 归档实施方案

## 目标

让星海对话在用户主动沉淀并确认后，才创建 `glimmer`，并把当时的对话状态归档为可回看的历史。

归档后的历史只读。用户从 Glimmer History 点击 glimmer 时，先进入 glimmer 详情页；详情页显示完整 glimmer，右上角提供历史入口，点击后进入原星海对话历史页。历史页不显示 composer，不显示 options，不能继续对话，但会显示归档中的工具结果，例如 resonance matches。

旧数据不做兼容，后续通过 db reset 清空。

## 产品流程

### 星海对话

1. 用户进入星海并开始对话。
2. 每轮对话仍使用 LangGraph checkpoint 维护运行时状态。
3. 当用户触发沉淀时，进入 `collect`。
4. 一旦进入 `collect`，当前 runtime thread 不再允许继续对话。
5. `collect` 只生成候选 glimmer 文本，不创建数据库记录。
6. 图进入 `confirm` 节点并中断，等待用户确认。

### 沉淀确认 Sheet

1. iOS 展示候选 glimmer。
2. Sheet 只有两个显式动作：`退出` 和 `确认`。
3. 没有编辑按钮。
4. 用户点击 glimmer 文本区域后，自动进入全屏 sheet 并聚焦编辑。
5. 用户可以修改候选 glimmer 文本。
6. 点击 `确认` 后，iOS 使用同一个 runtime thread resume LangGraph，并传入修改后的文本。
7. 点击 `退出` 后，弹出二次确认。
8. 二次确认退出后，放弃沉淀，丢弃这段 runtime thread，回到星海主页。

### 保存成功

1. `confirm` 恢复后进入 `glimmer` 节点。
2. `glimmer` 节点创建 `glimmers` 记录。
3. 同一事务内将归档 timeline 写入 `glimmer_messages`。
4. 后端返回保存成功事件。
5. iOS 退出到星海主页。

### Glimmer History

1. History 卡片中 glimmer 内容最多显示 3 行。
2. 点击卡片进入 glimmer 详情页。
3. Glimmer 详情页显示完整 glimmer 内容。
4. 详情页右上角有历史图标。
5. 点击历史图标进入只读星海历史页。
6. 历史页读取 `glimmer_messages`。
7. 历史页显示普通消息和工具结果，包括 matches。
8. 历史页不显示 options，不显示 composer，不能继续对话。
9. 沉淀后的 glimmer 暂时不允许编辑。

## 数据库方案

### 新增 `glimmer_messages`

使用事件式结构，而不是为 matches 单独建列，避免未来新增更多 tool 时反复迁移表结构。

```sql
CREATE TABLE public.glimmer_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    glimmer_id UUID NOT NULL REFERENCES public.glimmers(id) ON DELETE CASCADE,
    sequence INT NOT NULL,
    type TEXT NOT NULL,
    role TEXT CHECK (role IN ('user', 'assistant')),
    content TEXT,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT glimmer_messages_content_or_payload_check
    CHECK (
        NULLIF(trim(COALESCE(content, '')), '') IS NOT NULL
        OR payload <> '{}'::jsonb
    )
);

CREATE UNIQUE INDEX glimmer_messages_glimmer_sequence_idx
    ON public.glimmer_messages (glimmer_id, sequence);

CREATE INDEX glimmer_messages_user_glimmer_sequence_idx
    ON public.glimmer_messages (user_id, glimmer_id, sequence);
```

### RLS

`glimmer_messages` 属于用户数据，启用 RLS。

客户端只需要读自己的归档历史，不需要直接插入、更新、删除。写入由后端 service role 完成。

```sql
ALTER TABLE public.glimmer_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to view their own glimmer messages"
    ON public.glimmer_messages FOR SELECT
    USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Deny users from inserting glimmer messages"
    ON public.glimmer_messages FOR INSERT
    WITH CHECK (false);

CREATE POLICY "Deny users from updating glimmer messages"
    ON public.glimmer_messages FOR UPDATE
    USING (false) WITH CHECK (false);

CREATE POLICY "Deny users from deleting glimmer messages"
    ON public.glimmer_messages FOR DELETE
    USING (false);
```

### 事件类型

第一阶段支持：

- `message`: 用户或星海的普通可见消息。
- `tool_result`: 工具结果，例如 resonance matches。

保留未来扩展空间：

- `reflection`: 结构化洞察。
- `quote`: 引文或来源。
- `image`: 图像或视觉卡片。
- `system_note`: 产品可见提示，不等同于 LLM system prompt。

示例：

```json
[
  {
    "type": "message",
    "role": "user",
    "content": "我最近总觉得自己在慢慢远离某些东西。",
    "payload": {}
  },
  {
    "type": "message",
    "role": "assistant",
    "content": "你像是在靠近某个还没有命名的潮汐。",
    "payload": {}
  },
  {
    "type": "tool_result",
    "role": null,
    "content": null,
    "payload": {
      "tool": "resonance_match",
      "items": [
        { "name": "庄子", "line": "..." },
        { "name": "Virginia Woolf", "line": "..." }
      ]
    }
  }
]
```

## LangGraph 方案

### 图结构

调整星海图为：

```text
START
  -> router
  -> starsea
  -> END

router
  -> collect
  -> confirm
  -> glimmer
  -> END
```

`router` 根据 intent 决定走普通对话还是沉淀流程。

### State 优化

继续保留 LangChain 原始 `messages` 给模型上下文使用，同时新增产品层归档 timeline。

```python
class State(TypedDict):
    messages: Annotated[list[AnyMessage], add_messages]
    display: Display | None
    archive_events: Annotated[list[ArchiveEvent], operator.add]
    pending_glimmer: str | None
    confirmed_glimmer: str | None
    metadata: dict[str, Any]
```

`messages` 用于推理和 checkpoint。

`archive_events` 用于最终写入 `glimmer_messages`，只包含用户实际应看到的历史片段。不要把 system message、tool internal message、调试信息写入 `archive_events`。

### 普通对话节点

每轮用户输入时追加：

```python
{"type": "message", "role": "user", "content": content, "payload": {}}
```

星海回复完成后追加：

```python
{"type": "message", "role": "assistant", "content": visible_reply, "payload": {}}
```

如果本轮产生 resonance matches，追加：

```python
{
    "type": "tool_result",
    "role": None,
    "content": None,
    "payload": {
        "tool": "resonance_match",
        "items": matches
    }
}
```

归档内容必须去除 options markup。Options 只属于实时对话 UI，不进入归档。

### Collect 节点

`collect` 根据当前 `messages` 和 `archive_events` 生成候选 glimmer。

它只更新：

- `pending_glimmer`
- `display`

它不创建数据库记录。

### Confirm 节点

`confirm` 是 human-in-the-loop 中断节点。

要求：

1. `interrupt(...)` 尽量放在节点最前面。
2. 不在 `interrupt(...)` 前后做任何写库副作用。
3. resume payload 必须 JSON-serializable。
4. 如果用户确认，则写入 `confirmed_glimmer` 并跳到 `glimmer`。
5. 如果用户退出，则结束图，不创建任何记录。

Resume payload：

```json
{
  "approved": true,
  "content": "用户最终确认或修改后的 glimmer 文本"
}
```

退出 payload：

```json
{
  "approved": false
}
```

### Glimmer 节点

`glimmer` 是唯一允许写入数据库的节点。

它必须在一个事务里完成：

1. 创建 `glimmers`。
2. 将 `archive_events` 规范化为 `glimmer_messages`。
3. 使用新创建的 `glimmer.id` 作为每条消息的 `glimmer_id`。
4. 返回 settled display。

必须防止重复写入：

- `confirm` 不写库。
- `glimmer` 节点中可检查 state 是否已有已创建的 `glimmer_id`。
- 或在服务层为 runtime thread 增加幂等保护。

## API 方案

### 当前流式接口继续承担普通对话和 collect

`POST /starsea`

普通对话：

```json
{
  "threadId": "...",
  "content": "..."
}
```

触发沉淀：

```json
{
  "threadId": "...",
  "content": null,
  "intent": "collect"
}
```

当图到达 `confirm` interrupt 时，SSE 返回：

```json
{
  "type": "confirm_required",
  "threadId": "...",
  "glimmer": {
    "content": "候选 glimmer 文本"
  }
}
```

### 新增或扩展 resume 接口

可新增：

`POST /starsea/resume`

确认保存：

```json
{
  "threadId": "...",
  "resume": {
    "approved": true,
    "content": "用户修改后的 glimmer 文本"
  }
}
```

确认退出：

```json
{
  "threadId": "...",
  "resume": {
    "approved": false
  }
}
```

保存成功返回：

```json
{
  "type": "settled",
  "threadId": "...",
  "glimmer": {
    "id": "...",
    "content": "...",
    "createdAt": "..."
  }
}
```

退出成功返回：

```json
{
  "type": "discarded",
  "threadId": "..."
}
```

## iOS 实施方案

### StarSeaConversationView

调整状态：

- 新增 `pendingGlimmerText`
- 新增 `isConfirmingSettlement`
- 新增 `isDiscardConfirmationPresented`
- collect 后禁用 composer 和 options
- collect 后不允许继续发消息

原来的 `settledGlimmer` 逻辑改为：

- collect 返回 `confirm_required` 时展示确认 sheet。
- 确认 sheet 中保存才会创建 glimmer。
- 保存成功后调用 `onLeave()` 回到星海主页。
- 退出确认后调用 resume approved=false 或本地丢弃，再 `onLeave()`。

### 沉淀 Sheet

新建或重构为 `StarSeaGlimmerConfirmationSheet`。

界面：

- 展示候选 glimmer 文本。
- 顶部或底部提供 `退出` 和 `确认`。
- 没有编辑按钮。
- 点击文本区域进入全屏编辑态。

编辑态：

- 使用 full-screen sheet 或 large detent。
- 自动 focus 文本编辑器。
- 用户修改文本后返回确认态。
- 确认按钮传修改后的文本给后端。

### Glimmer History

`GlimmerRecordsView`：

- 卡片内容最多 3 行。
- 卡片可点击。
- 点击进入 `GlimmerDetailView`。

`GlimmerDetailView`：

- 显示完整 glimmer。
- 不允许编辑。
- 右上角历史图标。
- 点击进入 `GlimmerConversationHistoryView`。

`GlimmerConversationHistoryView`：

- 加载 `glimmer_messages`。
- 按 `sequence` 排序。
- `message` 类型复用星海消息气泡。
- `tool_result` 且 `payload.tool == "resonance_match"` 时显示 matches。
- 未知类型默认隐藏，或以极简 fallback 展示。
- 不显示 composer。
- 不显示 options。
- 不允许继续对话。

### Swift 模型

新增模型：

```swift
struct GlimmerMessage: Identifiable, Decodable, Hashable {
    let id: UUID
    let glimmerId: UUID
    let sequence: Int
    let type: String
    let role: String?
    let content: String?
    let payload: JSONValue
    let createdAt: Date
}
```

如果项目已有 JSON helper，则复用；否则新增轻量 `JSONValue`。

新增查询：

```swift
static func getMessages(glimmerId: UUID) async throws -> [GlimmerMessage]
```

Supabase 查询：

```swift
.from("glimmer_messages")
.select("id, glimmer_id, sequence, type, role, content, payload, created_at")
.eq("glimmer_id", value: glimmerId)
.order("sequence", ascending: true)
```

## 后端实施步骤

1. 新建 Supabase migration，创建 `glimmer_messages`、索引和 RLS。
2. 新增 repository：
   - `create_glimmer_with_messages(...)`
   - 或 `create_glimmer(...)` + `insert_glimmer_messages(...)`，由服务层事务包裹。
3. 定义 `ArchiveEvent` 类型和规范化函数。
4. 优化 StarSea state，加入 `archive_events`、`pending_glimmer`、`confirmed_glimmer`。
5. 在普通 starsea 节点追加产品可见 `archive_events`。
6. 在 tool 产生结果时追加 `tool_result` 事件。
7. 修改 collect 节点：只生成 pending glimmer，不写库。
8. 新增 confirm interrupt 节点。
9. 新增 glimmer 写库节点。
10. 调整 runner 和 SSE 映射，支持 `confirm_required`、`settled`、`discarded`。
11. 新增 resume API 或扩展现有 `/starsea`。

## iOS 实施步骤

1. 更新 `StarSeaStreamService` 事件类型。
2. 支持 collect 返回 `confirm_required`。
3. 支持 resume confirm/discard。
4. 重构 `StarSeaConversationView` 的沉淀状态机。
5. 新建沉淀确认 sheet。
6. 新增 `GlimmerMessage` 模型和查询方法。
7. 重构 `GlimmerRecordsView`：3 行卡片、导航到详情。
8. 新建 `GlimmerDetailView`。
9. 新建 `GlimmerConversationHistoryView`。
10. 抽取可复用的只读星海历史消息列表。

## 验证清单

### 后端

- 普通星海对话仍可连续多轮。
- 每轮对话都会在 state 中形成干净 `archive_events`。
- Options 不进入 `archive_events`。
- Collect 不创建 glimmer。
- Confirm interrupt 能正确返回候选 glimmer。
- Resume approved=false 不创建任何记录。
- Resume approved=true 创建 glimmer 和 glimmer_messages。
- 写库事务失败时不会只创建一半数据。
- 重复 resume 不会重复创建 glimmer。

### 数据库

- `glimmer_messages` RLS 正确。
- 用户只能读自己的归档消息。
- 客户端不能直接 insert/update/delete。
- 删除 glimmer 时，对应 glimmer_messages 级联删除。

### iOS

- collect 后 composer 和 options 消失或禁用，不能继续对话。
- 沉淀 sheet 显示候选 glimmer。
- 点击文本进入全屏编辑并自动聚焦。
- 退出会二次确认。
- 确认退出后回到星海主页。
- 确认保存后回到星海主页。
- History 卡片最多 3 行。
- 点击卡片进入完整详情页。
- 历史图标进入只读对话历史。
- 历史页显示 message 和 resonance matches。
- 历史页不显示 options，不显示 composer。

## 需要避免的点

- 不从 LangGraph checkpoint 直接渲染历史页。
- 不在 `confirm` 节点写库。
- 不把 options markup 写入 `glimmer_messages`。
- 不为每个 tool 单独加数据库列。
- 不让客户端直接写 `glimmer_messages`。
- 不在沉淀后的 glimmer 上保留编辑入口。
