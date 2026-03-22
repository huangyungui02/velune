# Aevra 架构优化 TODO

目标：收敛 `glimmer -> echo -> chat` 的状态流，统一本地缓存与远端同步边界，减少补偿式刷新，让 iOS 侧成为稳定的 local-first 体验。

## 一、原则

- 领域模型继续分开：`glimmer` 与 `echo` 分表、分概念。
- 应用命令收拢：提交心光与生成回响应是一次完整意图，不由客户端手动编排多步写操作。
- 本地优先：UI 只读本地 store，本地先落库，再由同步层向远端推进。
- 单一真源：同一份数据只应有一个权威持有者，避免 `View`、`Manager`、远端接口共同拥有状态。
- 同步显式化：失败、重试、处理中、已同步都必须有明确状态，而不是靠“重新拉一下”补偿。

## 二、当前主要问题

- `MatchingManager` 负责“先创建 glimmer，再 stream echo”，客户端承担了本应由服务端承担的编排。
- `MatchingManager.currentGlimmer`、SwiftData、`GlimmerView` 本地 `@State` 同时持有 glimmer，存在多源状态。
- `ProfileView` 只在本地为空时拉取远端，不是真正同步，长期会陈旧。
- `GlimmerView` 依赖 `refreshGlimmer()` 读后补偿，说明状态边界没有收敛。
- `glimmer/echo` 有本地持久化，`session/message` 没有，本地缓存策略不一致。
- `ChatView` 在发送完成后重新拉历史，是典型 read-after-write glue。

## 三、目标架构

### 1. 领域层

- 保留表结构分离：
  - `glimmers`
  - `echoes`
  - `sessions`
  - `messages`
- 保留 `glimmer.status` 作为服务端流程状态，但客户端需要自己的同步状态字段。

### 2. 应用层

- 引入单一命令：
  - `compose glimmer`
  - 语义：创建 glimmer 并生成 echoes
- 客户端只提交一次 intent，不再手动调用“create + stream”两步。
- 服务端负责：
  - 校验用户
  - 校验/扣减 credit
  - 创建或确认 glimmer
  - 切换状态到 `processing`
  - 生成 echoes
  - SSE 推送 `echo` / `done` / `error`

### 3. 本地存储层

- SwiftData 成为 `glimmer/echo` 的唯一真源。
- 后续将 `session/message` 也纳入 SwiftData，统一本地缓存模型。
- UI 不直接依赖网络返回体保存状态，只消费本地实体变化。

### 4. 同步层

- 引入统一同步协调器，例如：
  - `GlimmerSyncCoordinator`
  - `ChatSyncCoordinator`
- 职责：
  - 提交本地待同步对象
  - 监听 SSE
  - merge 远端结果到本地
  - 记录失败原因
  - 驱动重试

## 四、分阶段执行

## Phase 1：收敛 glimmer/echo 写路径

### TODO

- 设计新的后端接口，例如：
  - `POST /{lang}/glimmers/compose`
- 请求建议包含：
  - `glimmerId`
  - `content`
- SSE 返回事件统一为：
  - `ready`
  - `echo`
  - `done`
  - `error`
- 服务端内部完成：
  - 幂等创建 glimmer
  - 状态迁移
  - echo 生成
  - credit snapshot 返回
- iOS 废弃“先 `Glimmer.create` 再 `EchoStreamService.stream`”的双调用流程。

### 验收标准

- iOS 创建一条 glimmer 只发起一次业务请求。
- 网络中断、用户离开页面、服务端报错时，状态仍然可恢复。
- 服务端能根据 `glimmerId` 做幂等处理，避免重复生成 echoes。

## Phase 2：建立本地同步状态机

### TODO

- 给 `Glimmer` 增加本地同步字段：
  - `syncState`
  - `lastSyncedAt`
  - `retryCount`
  - `syncError`
- `syncState` 建议枚举：
  - `queued`
  - `syncing`
  - `synced`
  - `failed`
- 明确状态关系：
  - `status` 表示服务端业务状态
  - `syncState` 表示客户端同步状态
- 提交 glimmer 时先写本地：
  - 插入 glimmer
  - `syncState = queued`
- 同步开始时：
  - `syncState = syncing`
- SSE 收到 echo 时：
  - 本地 upsert echo
- SSE 收到 done 时：
  - 更新 `status`
  - 更新 credit snapshot
  - `syncState = synced`
- 失败时：
  - `syncState = failed`
  - 写入 `syncError`

### 验收标准

- UI 可仅基于本地状态正确展示“处理中 / 已完成 / 失败”。
- 应用重启后仍可识别未完成 glimmer，并可重试。
- 不再依赖详情页手动 `refreshGlimmer()` 修正状态。

## Phase 3：消除多源状态

### TODO

- `MatchingManager` 不再持有完整 `currentGlimmer` 实体。
- `MatchingManager` 仅持有：
  - 当前 `glimmerId`
  - 当前任务运行状态
  - 当前错误
- `StarSeaView` 根据 `glimmerId` 从 SwiftData 读取 glimmer。
- `GlimmerView` 不再用独立 `@State private var glimmer` 持有副本。
- 所有视图改为直接观察 SwiftData 中的实体或按 id 查询结果。

### 验收标准

- `glimmer` 在应用内只有一个权威实体来源。
- 页面切换、返回、重进后，不会出现 UI 与本地数据不同步的问题。
- 代码中不再需要额外的“复制一份对象到本地 state”来维持显示。

## Phase 4：统一列表与详情同步策略

### TODO

- `ProfileView.refreshGlimmers()` 改为真正的“增量同步”，而不是“本地为空才拉远端”。
- 为 glimmer 列表设计拉取策略：
  - 首次进入：本地秒开 + 后台 reconcile
  - 下拉刷新：主动拉远端并 merge
  - 冷启动恢复：补齐未完成数据
- `GlimmerView` 进入详情时应直接展示本地数据。
- 若需要后台补齐，只通过统一同步层进行，而不是 view 自己发请求。

### 验收标准

- Profile 页不是一次性导入器，而是稳定的同步视图。
- 详情页不再直接承担远端修补职责。
- 新生成的 echo 能稳定在列表、详情、首页状态间保持一致。

## Phase 5：把 chat 也纳入 local-first

### TODO

- 将 `ChatSession`、`Message` 迁移到 SwiftData。
- 发送消息时先本地插入：
  - user message
  - assistant pending message
- 流式返回时只增量更新本地 assistant message。
- `done` 时只修正：
  - server message id
  - session id
  - title
  - timestamps
- 去掉 `finalizeSend()` 中重新 `Message.getHistory()` 的强依赖。
- 会话列表改为读本地 session store，远端只做增量同步。

### 验收标准

- 聊天页发送消息后无需“整页重拉”。
- 新会话从 draft 升级为正式 session 时，本地状态连续，不闪断。
- 历史消息、侧栏会话、当前对话三者来源一致。

## Phase 6：服务端收口与幂等治理

### TODO

- 为 compose 接口建立幂等语义：
  - 同一 `glimmerId` 重试不重复生成 echoes
- 校验 `glimmer.status` 状态迁移是否合法：
  - `pending -> processing -> complete/incomplete/failed`
- 把 credit 消耗与业务操作绑定在同一服务端命令边界内。
- 明确客户端取消连接时的处理：
  - 是否继续后台执行
  - 是否允许稍后重连取结果
- 评估是否需要增加查询接口：
  - `get pending/failed glimmers`
  - `resume compose by glimmerId`

### 验收标准

- 网络重试不会造成重复数据。
- 客户端中断连接不会让 glimmer 落入不明状态。
- 服务端状态流可解释、可恢复、可监控。

## 五、建议新增类型

- iOS
  - `GlimmerSyncState`
  - `GlimmerSyncCoordinator`
  - `ChatSyncCoordinator`
  - `GlimmerRepository`
  - `ChatRepository`
- Agent / Backend
  - `compose_glimmer` handler
  - `compose_glimmer` service
  - 幂等检查与状态迁移 helper

## 六、建议删除或弱化的旧模式

- 客户端手动串联：
  - `Glimmer.create()`
  - `EchoStreamService.stream()`
- View 自己做远端补偿刷新。
- “本地没有才去远端拉”的一次性缓存填充逻辑。
- 发送完成后整段历史重拉。
- `Manager` 与 `View` 共同持有同一实体副本。

## 七、执行顺序建议

1. 先改后端 compose 接口，收拢 glimmer/echo 命令边界。
2. 再改 iOS 的 `MatchingManager` 和首页提交流程。
3. 接着引入 `syncState`，消除 `currentGlimmer` 多源状态。
4. 然后改 `ProfileView` / `GlimmerView` 的同步方式。
5. 最后把 chat/session/message 纳入本地缓存，统一成完整 local-first。

## 八、交给 AI 时的任务拆分建议

可拆为以下独立任务：

- 任务 1：设计并实现新的 `compose glimmer` SSE 接口
- 任务 2：iOS 首页从“双请求”切到“单请求”
- 任务 3：为 `Glimmer` 增加本地同步状态字段
- 任务 4：移除 `currentGlimmer` 实体 ownership，改用 `glimmerId + store query`
- 任务 5：重写 `ProfileView` 的同步策略
- 任务 6：重写 `GlimmerView`，移除 view 内远端 refresh
- 任务 7：把 `ChatSession` / `Message` 接入 SwiftData
- 任务 8：聊天发送流程改为本地增量更新，不再全量重拉

## 九、最终完成标志

- 用户提交一条 glimmer 后，无论在线、断网恢复、切后台再回来，状态都自洽。
- 首页、列表页、详情页、聊天页看到的是同一份本地数据。
- 客户端不再负责拼接业务 saga，只负责表达 intent 与展示本地状态。
- 服务端负责业务原子性、幂等、credit、状态迁移。
