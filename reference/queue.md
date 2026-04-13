# Souler 异步生成队列方案

## 目标

将 `bio/profile` 与 `chapters` 从前台请求主链路剥离，改为可靠后台生成，避免：

* `echo` 冷启动等待过长
* FastAPI 进程重启导致 `asyncio.create_task` 任务丢失
* 多实例扩容时并发冲突与重复生成

---

## 总体架构

采用三层职责：

1. API 层（Railway FastAPI）
* 负责同步最小写入与入队
* 不执行重生成任务

2. 状态层（Supabase Postgres）
* `soulers`：主实体
* `souler_generation_status`：异步生成状态真相表
* `chapters`：章节结果表

3. 队列与执行层
* 队列：`pgmq`（Supabase Queues）
* 执行：Railway 独立 `worker service`

结论：不需要 Redis/Kafka。先用 Supabase + Railway 即可。

---

## 触发策略

### bio/profile

`souler` 创建后立即入队（eager）。

### chapters

不在 `echo` 匹配时立刻生成。采用 `lazy-but-automatic`：

* 用户打开 `ChatView`，且当前 `messages` 为空（例如新建 session）时检查章节状态
* 若章节仍未生成，则自动入队
* 若章节已生成完成，则直接展示章节 UI

这样可避免为大量“只匹配但未进入”的 souler 浪费生成成本，也能让章节体验只出现在真正需要它的空白会话入口。

---

## 数据模型

## 1) 状态表：`public.souler_generation_status`

```sql
create table if not exists public.souler_generation_status (
    souler_id uuid primary key references public.soulers(id) on delete cascade,

    bio_status text not null default 'pending',
    bio_error text,
    bio_attempt_count integer not null default 0,
    bio_updated_at timestamptz not null default now(),

    chapters_status text not null default 'pending',
    chapters_error text,
    chapters_attempt_count integer not null default 0,
    chapters_updated_at timestamptz not null default now(),

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint souler_generation_status_bio_status_check
        check (bio_status in ('pending', 'queued', 'processing', 'complete', 'failed')),
    constraint souler_generation_status_chapters_status_check
        check (chapters_status in ('pending', 'queued', 'processing', 'complete', 'failed'))
);
```

可选索引（后台筛选监控用）：

```sql
create index if not exists idx_souler_generation_status_bio_status
on public.souler_generation_status (bio_status);

create index if not exists idx_souler_generation_status_chapters_status
on public.souler_generation_status (chapters_status);
```

## 2) 队列

使用 `pgmq` 建立两个队列：

* `souler_bio_jobs`
* `souler_chapter_jobs`

消息体统一为最小字段：

```json
{
  "souler_id": "uuid",
  "lang": "zh"
}
```

---

## 状态机

每个任务类型（bio / chapters）独立流转：

* `pending`：未触发
* `queued`：已入队，等待消费
* `processing`：worker 正在执行
* `complete`：成功完成
* `failed`：达到重试上限后失败

---

## 入队规则（RPC）

建议通过 Postgres 函数统一入队，避免业务代码散落更新状态。

必须满足：

* `complete` 不重复入队
* `queued/processing` 不重复入队
* 入队与状态更新必须在同一事务中完成（单 RPC 原子化）

推荐实现方式（关键）：

* 将 `ensure_souler_generation_status + enqueue + status->queued` 收敛到同一个 RPC
* API 侧只调用一个入队 RPC，避免多次往返导致并发窗口
* RPC 返回时即可作为“是否真正入队”的唯一判断依据

建议提供（`ensure` 可作为内部 helper；API 对外只调用 enqueue RPC）：

* `public.ensure_souler_generation_status(p_souler_id uuid)`
* `public.enqueue_souler_bio_generation(p_souler_id uuid, p_lang text)`
* `public.enqueue_souler_chapter_generation(p_souler_id uuid, p_lang text)`

返回统一结构：

* `enqueued`（boolean）
* `status`（text）
* `message`（text）

---

## API 侧改造

## 1) Echo 链路

现状：新 souler 时同步生成 bio，拖慢首包。

目标改造：

1. 命中新 souler -> 仅最小创建 souler
2. 调用 `ensure_souler_generation_status`
3. 调用 `enqueue_souler_bio_generation`
4. 立即继续 echo 生成，不等待 bio

## 2) Chapters 入口

在用户打开 `ChatView` 且 `messages` 为空时：

1. 读取 `souler_generation_status.chapters_status`
2. 若 `complete` -> 直接展示章节 UI
3. 若 `pending/failed` -> 调 `enqueue_souler_chapter_generation`
4. 若 `queued/processing` -> 展示占位态，而非 skeleton

补充约束：

* 章节入口只出现在空白会话中
* 一旦 `messages` 非空，界面进入正常对话态，不再展示章节空态
* `pending` 与 `processing` 的视觉表达尽量统一，避免让用户感知到“系统正在加载列表”

---

## Railway Worker 设计

新增独立 service（与 API 分离）：

* API service：`uvicorn ...`
* Worker service：`python -m app.worker.main`

Worker 主循环：

1. 批量读取 `souler_bio_jobs`
2. 逐条处理并 ack（delete）
3. 批量读取 `souler_chapter_jobs`
4. 逐条处理并 ack（delete）
5. 无消息时 sleep `1~2s`

### 处理流程（以 bio 为例）

1. 解析消息 `souler_id/lang`
2. 若状态已 `complete`：直接 ack（幂等短路）
3. 仅在 `status = queued` 时更新为 `processing`，并 `bio_attempt_count + 1`（CAS 条件更新）
4. 拉取 souler 最新数据并生成 bio
5. 写入 `soulers.bio`
6. 仅在 `status = processing` 时置 `complete`，清空 `bio_error`（防止并发覆盖）
7. ack 队列消息

失败时：

1. 记录 `bio_error`
2. 判断 attempt 是否超限
3. 未超限：按退避策略重入队，状态回 `queued`
4. 超限：状态置 `failed`
5. 当前消息 ack（避免毒消息反复阻塞）

---

## 重试策略

推荐初始值：

* bio：最多 `3` 次，退避 `60s -> 300s`
* chapters：最多 `2` 次，退避 `180s`

Worker 启动恢复：

* 扫描长时间 `processing`（如超过 10 分钟）任务
* 回置为 `queued` 或按 attempt 标记 `failed`

可观测性（上线前必须补齐）：

* 每次消费记录结构化日志：`job_id`、`souler_id`、`task_type`、`attempt`、`status_before`、`status_after`、`latency_ms`
* 指标至少包含：入队数、消费成功数、消费失败数、重试数、最终失败数、`processing` 超时回收数
* 监控告警至少包含：`failed` 增速异常、`processing` 长时间堆积、队列积压持续上升

---

## 幂等与一致性要求

* Worker 逻辑必须允许重复执行同一消息（至少一次投递语义）
* `chapters` 写入使用“全量覆盖 + 原子完成”策略：
  + 先删旧 chapters（同 souler）
  + 一次性写入 10 章
  + 成功后再置 `chapters_status = complete`
* 上述 `chapters` 的“删旧 + 插新 + 状态置 complete”必须在单事务内完成
* 若生成失败，不保留半套章节对外可见

---

## 前端展示约定

* `bio_status in ('queued', 'processing')`：展示短占位文案
* `ChatView` 中仅当 `messages` 为空时才检查并展示章节态
* `chapters_status = complete`：显示正式章节 UI
* `chapters_status in ('pending', 'queued', 'processing')`：显示一段克制的占位文案，例如“开始一段深度对话”，而非章节 skeleton
* `failed`：展示重试入口
* 若 `messages` 已非空，则不再展示章节占位或章节列表，直接进入正常聊天内容

---

## 渐进落地步骤

1. 新增 migration：`souler_generation_status` + `pgmq` 队列 + enqueue RPC
2. API 改造：echo 链路移除同步 bio 生成，改为入队
3. 新增 worker service：消费队列并落库
4. App 改造：读取状态并展示占位/失败/完成
5. 灰度：先 bio，后 chapters

---

## 当前项目的关键决策

* 保留 `soulers` 为主实体，不堆积异步状态字段
* 将生成状态集中在 `souler_generation_status`
* 队列用 `pgmq`，执行用 Railway worker
* 不使用进程内 `asyncio.create_task` 作为持久任务方案

---

## 上线前必做（补充）

1. 入队原子化：`ensure + enqueue + status 更新` 必须收敛为单 RPC 单事务。
2. 状态 CAS：`queued -> processing`、`processing -> complete/failed` 必须使用条件更新，禁止盲写。
3. chapters 单事务：`删旧 + 插新 + 置 complete` 必须同事务提交，避免空窗和半套数据。
4. 可观测性：补齐日志字段、核心指标和告警规则，否则线上问题难以定位。
