from __future__ import annotations

from taskiq_redis import RedisAsyncResultBackend, RedisStreamBroker

from app.core.config import get_settings

settings = get_settings()

result_backend = RedisAsyncResultBackend(
    redis_url=settings.REDIS_URL,
    result_ex_time=3600,
)

broker = RedisStreamBroker(
    url=settings.REDIS_URL,
    queue_name=settings.TASKIQ_QUEUE_NAME,
    consumer_group_name=f"{settings.TASKIQ_QUEUE_NAME}_workers",
).with_result_backend(result_backend)
