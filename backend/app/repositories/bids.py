from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.bid import Bid


def exists_for_auction(session: Session, auction_id: int) -> bool:
    return session.scalar(select(Bid.bid_id).where(Bid.auction_id == auction_id).limit(1)) is not None
