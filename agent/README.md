# Velune Agent (Python)

使用 Python + FastAPI 迁移 `supabase/functions/chat` 与 `supabase/functions/echo`。

## Endpoints

- `POST /chat`：SSE 流式对话（事件：`delta` / `done` / `error`）
- `POST /echo`：SSE 流式 echo 生成（事件：`echo` / `done` / `error`）
- `GET /health`：健康检查

## Local Run

```bash
uv sync
cp .env.example .env
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Required Env

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `DASHSCOPE_API_KEY`

可选：

- `DASHSCOPE_BASE_URL` (默认 `https://dashscope.aliyuncs.com/compatible-mode/v1`)
- `LLM_MODEL` (默认 `qwen-plus`)

## Railway Deploy

项目已包含：

- `Dockerfile`
- `railway.toml`

Railway 中配置同上环境变量后直接部署即可。
