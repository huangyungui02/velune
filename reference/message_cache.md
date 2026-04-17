# Messages / Sessions 缓存策略（单设备）

## 目标

- `sessions` 全量本地缓存，打开会话菜单时先本地秒开。
- `messages` 只缓存有限数量的 session，但对命中的 session 缓存其完整消息历史。
- `messages` 的 session 缓存池采用 FIFO，不做 LRU。
- 不改后端接口即可先落地。
- 当前只考虑单设备一致性，不处理跨设备实时同步冲突。

## 核心决策

- `sessions`：全量缓存。
- `messages`：固定只缓存最近进入缓存池的 `50` 个 session。
- FIFO 定义：
  - 一个 session 第一次被写入消息缓存时，进入队列尾部。
  - 若该 session 已在缓存池中，后续更新消息内容时，不调整其队列位置。
  - 当缓存池 session 数量超过上限时，删除队列头部最早进入缓存池的那个 session 的全部消息。

## 为什么这样做

- `sessions` 数据轻、复用高、列表价值高，适合完整持久化。
- `messages` 才是大头，不宜无限增长。
- 你要的是简单、稳定、可控，不是“理论上更优”的复杂策略。
- FIFO 比 LRU 更克制：
  - 实现简单。
  - 行为可预测。
  - 不需要在每次读取时改写访问时间。

## 适用范围

- iOS 本地缓存层。
- 存储介质：`SwiftData`。
- 鉴权范围：按 `user_id` 分桶。
- 匿名用户：不持久化消息缓存，不持久化 session 缓存。

## 现状

- 远端 `sessions` 已有 `updated_at`，适合做本地镜像和增量刷新。
- `ChatSession` 需要正式补上 `updatedAt` 字段，并以远端 `sessions.updated_at` 作为唯一来源。
- 远端 `messages` 目前是 `Message.getHistory(sessionId:)` 全量拉取。
- 当前 `ChatView.loadMessages()` 与 `finalizeSend()` 都会直接走远端。
- 当前项目已经有 `Resonance` 的 SwiftData 缓存模式，可复用同一思路。

相关代码位置：

- [Session.swift](/Users/bruce/Projects/aevra/ios/Velune/Velune/Models/Session.swift)
- [Message.swift](/Users/bruce/Projects/aevra/ios/Velune/Velune/Models/Message.swift)
- [ChatView+Conversation.swift](/Users/bruce/Projects/aevra/ios/Velune/Velune/Views/ChatView/ChatView+Conversation.swift)
- [DataContainer.swift](/Users/bruce/Projects/aevra/ios/Velune/Velune/Core/Persistence/DataContainer.swift)
- [sidebar_cache.md](/Users/bruce/Projects/aevra/reference/sidebar_cache.md)

## 缓存边界

### Sessions

- 全量缓存当前用户的所有 session。
- 本地数据按 `updatedAt DESC` 排序读取。
- 若某个 `souler` 下 `CachedChatSession` 数量为 `0`，即视为该 `souler` 本地无 session 缓存。
- 首次进入某个 `souler` 时，若本地还没有该 `souler` 对应的 session 缓存，则后台分页拉取该 `souler` 下全部远端 sessions，写入本地。
- 后续进入时先读本地秒开，再只拉远端第一页用于刷新最新状态，不需要每次都全量重拉。

### Messages

- 只对进入缓存池的前 `50` 个 session 持久化消息。
- 对于命中的 session，缓存该 session 的完整消息历史，不做“只保留最近 20 条 message”的二次裁剪。
- 不缓存草稿态 session。
- 一旦 draft session 在服务端落成真实 `session_id`，才允许写入消息缓存。

## 本地数据结构

建议新增 3 个 SwiftData 模型。

### 1. `CachedChatSession`

作用：本地镜像远端 `sessions`。

建议字段：

- `id: UUID`，唯一，对应远端 session id
- `userId: String`
- `soulerId: UUID`
- `chapterId: UUID?`
- `soulerName: String`
- `title: String`
- `createdAt: Date`
- `updatedAt: Date`

### 2. `CachedMessage`

作用：存某个已进入缓存池的 session 的完整消息历史。

建议字段：

- `id: UUID`，唯一，对应远端 message id
- `userId: String`
- `sessionId: UUID`
- `soulerId: UUID`
- `roleRaw: String`
- `content: String`
- `createdAt: Date`

说明：

- `roleRaw` 用字符串存，映射回 `Message.Role`。
- 排序按 `createdAt ASC`。

### 3. `MessageCacheBucket`

作用：记录哪些 session 正在消息缓存池内，以及 FIFO 顺序。

建议字段：

- `key: String`，唯一，格式 `"\(userId)#\(sessionId)"`
- `userId: String`
- `sessionId: UUID`
- `enqueuedAt: Date`
- `lastSessionUpdatedAt: Date`
- `lastSyncedAt: Date`
- `messageCount: Int`

说明：

- `enqueuedAt` 只在首次进入缓存池时写入一次，后续不改，用来维持 FIFO。
- `lastSessionUpdatedAt` 用于判断本地消息是否落后于 session 列表里的 `updatedAt`。
- `lastSyncedAt` 只是调试和观测辅助，不承担 TTL 语义。

## 存储挂载

在 [DataContainer.swift](/Users/bruce/Projects/aevra/ios/Velune/Velune/Core/Persistence/DataContainer.swift) 的 `Schema` 中新增：

- `CachedChatSession.self`
- `CachedMessage.self`
- `MessageCacheBucket.self`

保持和现有 `Resonance` 同一套 `SwiftData` 容器即可，不需要额外 store。

## 读取策略

### 打开会话菜单 / 进入 ChatView

1. 先读本地 `CachedChatSession`。
2. 若本地有值，立即渲染。
3. 若当前 `souler` 本地无任何 session 缓存：
   - 后台分页拉取该 `souler` 下全部远端 sessions。
   - 按 `id` 合并后回写本地。
   - “无任何 session 缓存”的判定口径是：该 `souler` 下 `CachedChatSession` 数量为 `0`。
4. 若当前 `souler` 本地已有 session 缓存：
   - 后台只拉远端第一页最新 session 列表。
   - 按 `id` 合并，若远端 `updatedAt` 更新则覆盖本地。
5. 合并后回写缓存，再刷新 UI。

### 打开某个已有 session

1. 先查 `MessageCacheBucket` 是否存在当前 `sessionId`。
2. 若存在，再取 `CachedMessage(sessionId)` 本地渲染。
3. 判断是否需要远端刷新：
   - 若本地 bucket 不存在：需要远端拉取。
   - 若本地 bucket 存在，但 `bucket.lastSessionUpdatedAt < currentSession.updatedAt`：需要远端拉取。
   - 其他情况：直接使用本地缓存，不额外请求。
4. 若走远端拉取：
   - 调 `Message.getHistory(sessionId:)`
   - 用返回结果覆盖该 session 的本地消息缓存
   - 若该 session 不在缓存池，则入队并执行 FIFO 淘汰

### 打开 draft session

- 不读消息缓存。
- 只展示当前内存态 `messages`。
- 服务端真正返回 `sessionId` 后，再写入缓存。

## 写入策略

### Session 写入

- `loadConversationSessions()` 拉到远端结果后，合并到 `CachedChatSession`。
- `finalizeSend()` 若创建了新 session，也要立即把对应 session 写入或更新到本地缓存。
- `startChapterSession()` 成功后同样写本地 session 缓存。

### Message 写入

以下时机写入消息缓存：

- `loadMessages()` 远端拉取成功后。
- `finalizeSend()` 远端补齐完整历史后。
- `startChapterSession()` 成功拿到第一条 assistant message 后。

写入规则：

1. 若 session 不在缓存池，先创建 `MessageCacheBucket`，写入 `enqueuedAt = now`。
2. 删除该 `sessionId` 旧的全部 `CachedMessage`。
3. 插入远端返回的新全量消息。
4. 更新 bucket：
   - `lastSessionUpdatedAt = 当前 session.updatedAt`
   - `lastSyncedAt = now`
   - `messageCount = messages.count`
5. 检查缓存池大小，若超限，按 FIFO 淘汰。

## FIFO 淘汰策略

设 `messageSessionCapacity = 50`。

每次消息缓存写入后：

1. 查询当前用户全部 `MessageCacheBucket`，按 `enqueuedAt ASC` 排序。
2. 若数量 `<= capacity`，不处理。
3. 若数量 `> capacity`，循环删除最老 bucket，直到回到上限。
4. 每删除一个 bucket，同时删除该 `sessionId` 下全部 `CachedMessage`。

注意：

- 已在缓存池中的 session，即使再次打开或收到新消息，也不改变 `enqueuedAt`。
- 这意味着它不会“续命”，这是有意为之，因为你要的是 FIFO，不是 LRU。

## 一致性规则

- `sessions` 与 `messages` 解耦：
  - `sessions` 是全量缓存。
  - `messages` 是有限 session 缓存。
- 若一个 session 仍在 `CachedChatSession` 中，但其消息已被 FIFO 淘汰：
  - 这是正常状态。
  - 用户重新点开时，再远端拉取并重新入队。
- 若 session 的 `updatedAt` 比 bucket 记录新：
  - 说明本地消息可能旧了。
  - 下次打开该 session 时强制刷新一次远端。

## 错误处理

### 会话列表

- 本地有缓存，远端失败：继续显示缓存，不打断用户。
- 本地无缓存，远端失败：显示错误态和重试按钮。

### 消息详情

- 本地有缓存，远端刷新失败：继续显示缓存，并可静默记录日志。
- 本地无缓存，远端失败：显示错误态。
- 本地写缓存失败：不影响当前聊天流程，但写日志。

## 清理策略

- 用户登出：不主动清空已登录用户缓存。
- 用户删除账号：清理该用户的 `CachedChatSession`、`CachedMessage`、`MessageCacheBucket`。
- 匿名用户切换为正式用户：匿名内存态不迁移到持久层。

## 不需要做的事

- 不需要 Supabase migration。
- 不需要新增后端接口。
- 不需要消息级增量同步。
- 不需要 TTL。
- 不需要跨设备合并。

## 推荐落地顺序

### Phase 1: Session 全量缓存

目标：先把会话列表做到秒开。

改动点：

- 新增 `CachedChatSession`
- 给 `ChatSession` 增加：
  - `fetchCached(userId:context:)`
  - `mergeCached(_:userId:context:)`
  - `clearCached(userId:context:)`
- 改 `loadConversationSessions()`：
  - 先读本地
  - 再远端静默刷新

### Phase 2: Message 有限缓存池

目标：聊天详情打开更快，减少重复拉取。

改动点：

- 新增 `CachedMessage`
- 新增 `MessageCacheBucket`
- 给 `Message` 增加：
  - `fetchCached(sessionId:userId:context:)`
  - `replaceCached(messages:sessionId:userId:sessionUpdatedAt:context:)`
  - `evictOverflowBuckets(userId:capacity:context:)`
  - `clearCached(userId:context:)`
- 改 `loadMessages()`：
  - 先读本地
  - 命中且未过期则直接返回
  - 否则远端拉取并覆盖写入

### Phase 3: 发送链路补齐缓存更新

目标：新消息到达后，本地缓存始终跟上。

改动点：

- `finalizeSend()`
- `startChapterSession()`
- 必要时在 `switchToExistingSession(...)` 完成后补一次 session cache merge

## 建议新增的常量

可以放在聊天模块内部，先不要做成全局配置。

```swift
enum ChatCachePolicy {
    static let messageSessionCapacity = 50
}
```

## 伪代码

```swift
@MainActor
func loadMessages() async {
    guard !isDraftSession else {
        messages = []
        return
    }

    let userId = try AuthManager.shared.getUserId().uuidString

    if let cached = try? Message.fetchCached(
        sessionId: activeSessionId,
        userId: userId,
        context: modelContext
    ), !cached.isEmpty {
        messages = cached
    }

    let session = sessions.first(where: { $0.id == activeSessionId })
    let shouldRefresh = Message.shouldRefreshCache(
        sessionId: activeSessionId,
        userId: userId,
        sessionUpdatedAt: session?.updatedAt,
        context: modelContext
    )

    guard shouldRefresh else { return }

    let remote = try await Message.getHistory(sessionId: activeSessionId)
    messages = remote

    try Message.replaceCached(
        messages: remote,
        sessionId: activeSessionId,
        userId: userId,
        sessionUpdatedAt: session?.updatedAt ?? .now,
        capacity: ChatCachePolicy.messageSessionCapacity,
        context: modelContext
    )
}
```

## 一个必要的小调整

当前 `ChatSession` 结构没有 `createdAt` / `updatedAt` 字段，但消息缓存是否需要刷新，必须知道 session 的 `updatedAt`。

所以建议顺手把 [Session.swift](/Users/bruce/Projects/aevra/ios/Velune/Velune/Models/Session.swift) 扩成：

- `createdAt: Date`
- `updatedAt: Date`

并在 `select(...)` 中补上：

- `created_at`
- `updated_at`

这是整个方案里唯一一个我认为必须补齐的数据点，否则消息缓存无法优雅判断新旧。

## 验收标准

- 打开 ChatView 后，会话菜单能先显示本地 session，再静默刷新。
- 命中缓存的 session，消息列表秒开。
- 超出 `N` 个已缓存 session 后，最早进入缓存池的 session 消息被清掉。
- 被淘汰的 session 重新打开时，能正常远端拉取并重新入队。
- 发送消息后，当前 session 的本地消息缓存与远端一致。
- 不引入草稿 session 的脏缓存。

## 最终结论

这件事可以按下面一句话落地：

- `sessions` 全量 SwiftData 缓存。
- `messages` 只缓存 `50` 个 session 的完整历史。
- 用 `MessageCacheBucket.enqueuedAt` 维持严格 FIFO。
- 用 `session.updatedAt` 判断消息缓存是否需要刷新。

这套方案足够干净，改动集中，技术上可直接实施。
