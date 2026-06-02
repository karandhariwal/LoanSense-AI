from celery import Celery
from app.core.config import settings

# Initialize the Celery application with Redis broker and backend
celery_app = Celery(
    "loansense_tasks",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
    include=["app.tasks"]
)

# Optional configuration settings
celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    # Celery configuration to prevent hanging on broker loss
    broker_connection_retry_on_startup=True
)
