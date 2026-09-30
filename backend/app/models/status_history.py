from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Identity, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class StatusHistory(Base):
    __tablename__ = "status_history"

    history_id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    entity_type: Mapped[str] = mapped_column(String(20), nullable=False)
    entity_id: Mapped[int] = mapped_column(Integer, nullable=False)
    old_status_code: Mapped[str | None] = mapped_column(String(40))
    new_status_code: Mapped[str] = mapped_column(String(40), nullable=False)
    changed_by: Mapped[int | None] = mapped_column(Integer)
    event_source: Mapped[str] = mapped_column(String(100), nullable=False, server_default="TRIGGER")
    changed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
