from datetime import datetime
from decimal import Decimal

from sqlalchemy import DateTime, ForeignKey, Identity, Numeric, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Auction(Base):
    __tablename__ = "auctions"

    auction_id: Mapped[int] = mapped_column(Identity(), primary_key=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.product_id", ondelete="RESTRICT"), nullable=False)
    status_id: Mapped[int] = mapped_column(ForeignKey("statuses.status_id", ondelete="RESTRICT"), nullable=False)
    base_price: Mapped[Decimal] = mapped_column(Numeric(15, 5), nullable=False)
    minimum_increment: Mapped[Decimal] = mapped_column(Numeric(15, 5), nullable=False)
    start_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
