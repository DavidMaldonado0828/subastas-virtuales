from sqlalchemy import case, select, func
from sqlalchemy.orm import Session

from app.models.bid import Bid
from app.models.auction import Auction
from app.models.user import User
from app.models.product import Product
from app.models.category import Category
from app.models.status import Status


def get_auction_for_bid(session: Session, auction_id: int) -> Auction | None:
    query = select(Auction).where(Auction.auction_id == auction_id)
    # PostgreSQL enforces the row lock. SQLite silently ignores FOR UPDATE;
    # omit it explicitly there so test behavior is clear and portable.
    if session.get_bind().dialect.name == "postgresql":
        query = query.with_for_update()
    return session.scalar(query)


def leader(session: Session, auction_id: int) -> Bid | None:
    return session.scalar(select(Bid).where(Bid.auction_id == auction_id).order_by(
        Bid.amount.desc(), Bid.bid_date.asc(), Bid.bid_id.asc()).limit(1))


def amount_exists(session: Session, auction_id: int, amount) -> bool:
    return session.scalar(select(Bid.bid_id).where(
        Bid.auction_id == auction_id, Bid.amount == amount).limit(1)) is not None


def add(session: Session, bid: Bid) -> None:
    session.add(bid)


def my_auction_rows(session: Session, participant_id: int, *, limit: int, offset: int,
                    status: str | None = None, now=None):
    # Aggregate personal high bid and join the current leader using a correlated subquery.
    leader_id = select(Bid.bid_id).where(Bid.auction_id == Auction.auction_id).order_by(
        Bid.amount.desc(), Bid.bid_date.asc(), Bid.bid_id.asc()).limit(1).correlate(Auction).scalar_subquery()
    leader_amount = select(Bid.amount).where(Bid.bid_id == leader_id).scalar_subquery()
    mine = func.max(Bid.amount).label("my_highest_bid")
    if now is None:
        from datetime import UTC, datetime
        now = datetime.now(UTC)
    temporal_state = case(
        (Status.code == "CANCELADA", "CANCELADA"),
        (Auction.end_date <= now, "CERRADA"),
        (Auction.start_date <= now, "ACTIVA"),
        else_="PROGRAMADA",
    )
    query = (
        select(Auction, Product, Category, Status.code, mine, leader_amount)
        .join(Bid, Bid.auction_id == Auction.auction_id)
        .join(Product, Auction.product_id == Product.product_id)
        .join(Category, Product.category_id == Category.category_id)
        .join(Status, Auction.status_id == Status.status_id)
        .where(Bid.participant_id == participant_id)
        .group_by(Auction.auction_id, Product.product_id, Category.category_id, Status.code)
    )
    if status is not None:
        query = query.where(temporal_state == status)
    ordering = case((temporal_state == "ACTIVA", 0), else_=1)
    return list(session.execute(query.order_by(ordering, Auction.created_at.desc(), Auction.auction_id.desc())
        .limit(limit).offset(offset)))


def history_rows(session: Session, auction_id: int, *, limit: int, offset: int):
    return list(session.execute(select(Bid, User.alias).join(User, Bid.participant_id == User.user_id)
        .where(Bid.auction_id == auction_id).order_by(Bid.amount.desc(), Bid.bid_date.asc(), Bid.bid_id.asc())
        .limit(limit).offset(offset)))


def exists_for_auction(session: Session, auction_id: int) -> bool:
    return session.scalar(select(Bid.bid_id).where(Bid.auction_id == auction_id).limit(1)) is not None
