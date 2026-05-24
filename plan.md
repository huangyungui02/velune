# Starsea 后端整合计划

## 目标

将 `seastar/` 测试项目中的 LangGraph 工作流整合进现有 `agent/` 后端，暴露 `/starsea` 接口供 iOS 调用。

iOS 写下 glimmer 后，请求 `/starsea`，后端以该 glimmer 为入口运行 Starsea graph，并返回可用于新 Starsea 结果页面渲染的 SSE 事件。前端 iOS 页面本轮不修改。

## 核心约定

- `thread_id` 等于 `glimmer_id`。
- 一个 glimmer 对应一条 Starsea 多轮对话记忆。
- LangGraph checkpoint 保存到现有 Supabase Postgres。
- 后端 repository 层从 SQLAlchemy asyncpg 迁移到 psycopg。
- 现有 repository 对外函数尽量保持不变，降低业务层改动面。
- LangGraph `AsyncPostgresSaver` 和 repository 查询复用同一个 `psycopg_pool.AsyncConnectionPool`。
- 迁移完成并验证后删除 `seastar/` 测试目录。

## 依赖调整

更新 `agent/pyproject.toml`：

- 移除 `sqlalchemy[asyncio]`。
- 添加：
  - `psycopg[binary,pool]`
  - `langgraph`
  - `langgraph-checkpoint-postgres`
  - `langchain-core`
  - `langchain-openai`
  - 如实际迁移需要，再添加 `langchain`

更新 `agent/uv.lock`。

## 数据库层改造

改造 `agent/app/repositories/database.py`：

- 使用 `psycopg_pool.AsyncConnectionPool` 替代 SQLAlchemy `AsyncEngine`。
- 保留现有公共 API：
  - `init_database()`
  - `close_database()`
  - `fetch_one()`
  - `fetch_all()`
  - `execute()`
  - `execute_fetch_one()`
- 新增或保留一个获取 pool 的函数，例如 `get_pool()`，供 LangGraph checkpoint 复用。
- pool 连接配置使用 `row_factory=dict_row`。
- SQL 参数风格从 SQLAlchemy `:name` 转换到 psycopg `%(name)s`。
- 保持返回值 JSON-ready 行为，包括 `datetime`、`date`、`UUID` 转换。
- 保持 repository timeout 行为。

需要检查并更新所有 SQL 调用点，确保参数占位符符合 psycopg。

## LangGraph 整合

从 `seastar/app/agent` 迁移核心 graph 代码到：

```text
agent/app/services/starsea/
  __init__.py
  checkpoint.py
  graph.py
  runner.py
  state.py
  messages.py
  llm.py
  nodes/
    __init__.py
    router/
    starsea/
    collect/
  tools/
    __init__.py
    match.py
```

不迁移：

- `seastar/frontend`
- `seastar/app/api`
- `seastar/app/main.py`
- `seastar/app/config`
- `seastar/Dockerfile`
- `seastar/scripts`

### Graph 行为

保留现有流程：

```text
START -> router -> starsea | collect -> END
```

保留现有输出：

- `starsea`
  - `type`
  - `content`
  - `thought_matches`
- `collect`
  - `type`
  - `content`

### Checkpoint

新增 `agent/app/services/starsea/checkpoint.py`：

- 从 `app.repositories.database.get_pool()` 获取同一个 psycopg pool。
- 初始化 `AsyncPostgresSaver`。
- app 启动时调用 `setup()` 创建或更新 LangGraph checkpoint 表。
- 编译 graph 时注入 checkpointer。
- app 关闭时随数据库 pool 一起关闭。

## `/starsea` 接口

在 `agent/app/api/routes.py` 新增：

```text
POST /starsea
```

### 鉴权

复用现有 `require_user_id()`，要求 `Authorization` header。

### 请求体

```json
{
  "glimmerId": "uuid",
  "content": "optional fallback",
  "metadata": {}
}
```

### glimmer 校验

优先通过 `user_id + glimmer_id` 从 `glimmers` 表读取内容。

- 找不到 glimmer：返回错误。
- glimmer 不属于当前用户：返回错误。
- 如果数据库内容为空，可使用 `content` 作为兜底。
- 如果两者都为空，返回错误。

### Graph 调用

```python
thread_id = str(glimmer_id)
config = {"configurable": {"thread_id": thread_id}}
```

每一轮请求只追加当前 human message，历史由 Postgres checkpoint 恢复。

### SSE 事件

建议统一为现有后端 SSE 风格，即每条都是 `data:` JSON：

```json
{ "type": "ready", "threadId": "..." }
{ "type": "delta", "delta": "..." }
{ "type": "thought_matches", "matches": [{ "name": "...", "whisper": "..." }] }
{ "type": "done", "threadId": "...", "display": { "type": "starsea", "content": "...", "thought_matches": [] } }
{ "type": "error", "message": "..." }
```

## iOS 暂不修改

本轮不改 iOS UI。

后续 iOS 可新增独立 Starsea 结果 view，不复用现有 `StarSeaView`。该 view 只需要：

- 写入 glimmer 后调用 `/starsea`。
- 使用 `glimmer.id` 作为多轮会话标识。
- 消费 SSE 的 `delta`、`thought_matches`、`done`。

## 删除测试目录

整合并验证通过后删除：

```text
seastar/
```

注意：当前 `seastar/` 是未跟踪目录，删除前确认核心代码已迁入 `agent/`。

## 验证清单

- `uv sync` 成功。
- 后端 app 可导入。
- FastAPI lifespan 能初始化 psycopg pool。
- LangGraph checkpoint `setup()` 成功。
- 现有 chat 路由数据库读写不回归。
- `/starsea` 未登录请求返回 401。
- `/starsea` 传不存在 glimmer 返回错误。
- `/starsea` 传当前用户 glimmer 返回 SSE。
- 第二次用同一个 `glimmerId` 调用 `/starsea` 能接续 LangGraph checkpoint。
- 删除 `seastar/` 后项目仍可通过基础检查。

## 风险点

- psycopg 参数占位符与 SQLAlchemy 不同，需要完整扫描 SQL。
- Supabase 连接串如果使用 pooler，psycopg pool 参数可能需要适配。
- LangGraph checkpoint 表由官方 `setup()` 创建，后续若要求所有 DDL 走 Supabase migration，需要再固化成迁移文件。
- `graph.astream(..., stream_mode="custom")` 的事件格式需要和当前 LangGraph 版本实际输出对齐。
