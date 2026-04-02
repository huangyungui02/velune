# Sidebar Resonance 缓存策略（单设备）

## 目标

- 打开 sidebar 时秒开（先显示本地缓存）。
- 后台静默更新，不打断当前交互。
- 不做 TTL 新鲜度判断。
- 仅考虑单设备一致性，不处理跨设备同步冲突。

## 缓存范围

- 缓存对象：`resonances` 列表（用于 sidebar）。
- 作用域：按 `user_id` 分桶缓存。
- 存储位置：
  - `Resonance` 数据落 `SwiftData`。
  - `SidebarSyncState` 落 `UserDefaults`（轻量同步状态）。

## 缓存数据结构

- `Resonance`：落 `SwiftData`，主键 `id`，包含 `soulerId`、`soulerName`、`lastSessionId`、`lastSessionTitle`、`updatedAt`、`userId`。
- `SidebarSyncState`（每个 `userId` 一条）：
  - `lastSyncedAt: Date?`（增量同步游标，取服务端返回最大 `updated_at`）
  - `hasMore: Bool`（用于记住是否还有下一页）

## 读取策略（打开 sidebar）

1. 先读本地缓存并立即渲染。
2. 立即触发后台静默增量同步（不显示全屏 loading）。
3. 增量结果合并完成后，若有变化再刷新 UI。

## 增量同步策略（静默）

1. 若 `lastSyncedAt` 为空：走首次全量第一页拉取（`limit = pageSize, offset = 0`）。
2. 若 `lastSyncedAt` 有值：请求 `updated_at >= lastSyncedAt` 的增量数据。
3. 为避免同时间戳边界漏数据，可使用轻微重叠窗口（例如 `lastSyncedAt - 1s`）再本地去重。
4. 合并后按 `updated_at DESC` 重排。
5. 更新 `lastSyncedAt = max(items.updated_at)`，并回写本地缓存。

## 合并规则

- 主键：`id`
- 同 `id` 冲突：保留 `updated_at` 更新的版本。
- 新增或更新项进入列表顶部（排序后自然到位）。
- 不做本地裁剪，完整保留本机已同步 resonance 列表。

## 分页策略（load more）

1. `loadMore` 继续走分页接口（`offset` / `limit`）。
2. 返回结果与当前列表按 `id` 去重合并。
3. `offset` 直接使用当前本地条数 `resonances.count`，不单独持久化。
4. `hasMore` 可由本次分页结果更新并写回 `SidebarSyncState`。

## 失效策略

- 用户登出：不做任何清理。
- 删除账号：清理该用户 resonance 缓存。
- 匿名用户：不持久化 resonance 缓存。

## 错误处理

- 静默增量失败但本地有缓存：继续展示缓存，不打断用户。
- 本地无缓存且请求失败：展示错误态与重试按钮。

## 不做的事（当前范围外）

- 不做跨设备同步对齐。
- 不做 TTL 新鲜度判定。
- 不引入数据库 migration。
