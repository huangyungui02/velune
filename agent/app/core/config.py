from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    APP_NAME: str = "velune-agent"

    DATABASE_URL: str
    REDIS_URL: str = "redis://127.0.0.1:6379/0"
    TASKIQ_QUEUE_NAME: str = "souler_resolution"
    LANGGRAPH_CHECKPOINT_TTL_MINUTES: int = 1440

    SUPABASE_URL: str
    SUPABASE_SERVICE_ROLE_KEY: str

    DASHSCOPE_API_KEY: str = Field(min_length=1)
    DASHSCOPE_BASE_URL: str = "https://dashscope.aliyuncs.com/compatible-mode/v1"

    CHAT_TEMPERATURE: float = 0.5
    MODEL_XS_TEMPERATURE: float = 0.1
    MODEL_S_TEMPERATURE: float = 0.25
    MODEL_M_TEMPERATURE: float = 0.5
    MODEL_L_TEMPERATURE: float = 0.75
    REPO_TIMEOUT_SECONDS: float = 12.0
    CHAT_HISTORY_LIMIT: int = 30

    LANGFUSE_ENABLED: bool = True
    LANGFUSE_PUBLIC_KEY: str | None = None
    LANGFUSE_SECRET_KEY: str | None = None
    LANGFUSE_BASE_URL: str | None = None


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
