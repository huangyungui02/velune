# 代码风格

原生，干净，简洁。

优先使用 Python 标准库、FastAPI、Pydantic、LangChain/LangGraph、Taskiq 和项目内已有工具；不要为了局部需求引入新的抽象层或依赖。

# 作用域

本文件适用于 `agent/` 子目录。

这是 Velune 的 Agent 服务，技术栈为 Python 3.14、FastAPI、LangChain/LangGraph、Taskiq、Supabase/Postgres、Redis checkpoint/queue。

# 项目结构

- `app/main.py`：FastAPI 应用入口和生命周期管理。
- `app/api/`：路由聚合、HTTP 依赖和接口边界。
- `app/core/`：配置、错误、LLM、SSE 等共享基础设施。
- `app/db/`：数据库连接和会话管理。
- `app/auth/`：Supabase Auth 客户端、依赖和仓储。
- `app/chat/`：聊天接口、schemas、repositories、services、prompts。
- `app/starsea/`：LangGraph 状态、节点、工具、runner、streaming、checkpoint。
- `app/soulers/`：Souler 内容、解析和画像生成逻辑。
- `app/tasks/`：Taskiq broker 与后台任务。

# 实现原则

- 保持模块边界清楚：API 层只做请求/响应和依赖装配，业务逻辑放在 `services/`，数据访问放在 `repositories/`。
- 优先组合现有函数和类型；只有在重复逻辑已经清晰出现时再提取新抽象。
- 不写“转发型” helper。单一调用点、只改名、只传参、只包一层 SDK/框架调用的函数应内联，除非名字本身承载明确业务语义。
- 不为可选未来需求提前开放参数、模式或覆盖点。先写当前真实路径，需要第二个真实调用方时再抽象。
- 使用显式类型标注。公共函数、服务入口、repository 方法和 LangGraph state 必须清楚表达输入输出。
- 异步路径保持全异步；不要在请求处理、streaming、graph node、task 中引入阻塞 IO。
- 错误处理应贴近边界：领域错误在服务层表达，HTTP 状态在 API 层转换。
- 不吞异常。需要降级时保留可观测信息，并让调用方能判断真实状态。
- 不把环境变量散落在业务代码中；统一通过 `app/core/config.py` 的 settings 读取。
- Settings、Pydantic schema、数据库约束和 SDK 类型已经校验过的值，下游不再重复 `if not ...`、类型检查、默认值兜底或格式清洗。
- 只保留业务不变量的校验；输入形状、必填、长度、枚举、默认值等边界校验放回 schema、Settings 或 migration。
- 不为了“保险”加宽泛 fallback、兼容分支、静默默认值或捕获所有异常。需要容错时必须对应明确产品行为或外部系统故障模式。

# FastAPI

- 路由函数保持薄，使用依赖注入获取认证、数据库、配置或服务对象。
- 响应模型和请求模型使用 Pydantic schema，避免直接暴露数据库行或第三方 SDK 对象。
- Streaming/SSE 相关代码要保持事件格式稳定，新增事件类型时同步检查前端消费方。
- 生命周期资源放在 `lifespan` 或对应 manager 中管理，避免模块 import 时创建网络连接。

# LangChain / LangGraph

- 修改 LangChain、LangGraph、checkpoint、middleware、tool calling 等版本敏感接口前，先用 Context7 查询最新官方文档。
- Graph state 应尽量小而稳定，避免把可重新计算的大对象、连接对象或 SDK client 放入 state。
- Node 函数保持单一职责：读取 state，调用明确的 service/tool，返回 state patch 或事件。
- Tool 输入输出要可序列化、可测试，并避免隐藏的全局状态。
- Prompt 修改要保留产品语气和安全边界，避免把结构化业务规则埋进散文式 prompt。

# 数据库与 Supabase

- 数据访问集中在 `repositories/` 或 `app/db/`，不要在 API、graph node、task 中散写 SQL 或 Supabase 查询。
- 涉及 Supabase、Postgres schema、RLS、Auth、Edge Functions 或 Storage 时，使用 Supabase 相关工具/技能确认真实状态。
- SQL 查询优先参数化，避免字符串拼接。
- 不在代码中写入密钥、JWT、连接串或用户隐私数据。

# Taskiq / 后台任务

- 后台任务必须可重试或具备明确的幂等边界。
- 任务参数保持小而可序列化；传 ID，不传大型对象或连接对象。
- Worker 专用逻辑不要影响 API 进程启动路径，注意 `broker.is_worker_process` 的分支。

# 测试与验证

- 小改动至少运行相关静态检查或最小可行测试。
- 修改 FastAPI 路由时，优先补充或运行接口级测试。
- 修改 LangGraph、streaming、checkpoint、Taskiq 任务时，要验证正常路径、失败路径和取消/重试边界。
- 本项目使用 `uv` 管理 Python 环境；常用命令形如：
  - `uv run python -m compileall app`
  - `uv run pytest`

# 文档查询

遇到版本敏感、接口易变、或需要确认最新官方用法时，用 Context7 查文档。

尤其是 FastAPI、Pydantic、LangChain、LangGraph、Taskiq、Supabase Python SDK、psycopg、Redis checkpoint 相关 API。
