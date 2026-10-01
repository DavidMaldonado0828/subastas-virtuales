from datetime import datetime
from decimal import Decimal

from sqlalchemy import DateTime, ForeignKey, Identity, Numeric, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Bid(Base):
    __tablename__ = "bids"

    bid_id: Mapped[int] = mapped_column(Identity(), primary_key=True)
    auction_id: Mapped[int] = mapped_column(ForeignKey("auctions.auction_id", ondelete="RESTRICT"), nullable=False)
    participant_id: Mapped[int] = mapped_column(ForeignKey("users.user_id", ondelete="RESTRICT"), nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    bid_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
