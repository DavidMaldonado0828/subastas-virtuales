from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Identity, String, func
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import text

from app.db.base import Base


class Status(Base):
    __tablename__ = "statuses"

    status_id: Mapped[int] = mapped_column(Identity(), primary_key=True)
    code: Mapped[str] = mapped_column(String(40), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(60), nullable=False)
    description: Mapped[str | None] = mapped_column(String(200))
    enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class StatusApplicability(Base):
    __tablename__ = "status_applicability"

    status_id: Mapped[int] = mapped_column(
        ForeignKey("statuses.status_id", ondelete="RESTRICT"), primary_key=True
    )
    entity_type: Mapped[str] = mapped_column(String(20), primary_key=True)
