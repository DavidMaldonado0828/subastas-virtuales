from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.auction import Auction
from app.models.bid import Bid
from app.models.category import Category
from app.models.product import Product
from app.models.status import Status
from app.models.user import User


def get_user_for_update(session: Session, user_id: int) -> User | None:
    return session.scalar(select(User).where(User.user_id == user_id).with_for_update())


def list_auctions(session: Session, *, limit: int, offset: int, status: str | None):
    leader_id = select(Bid.bid_id).where(Bid.auction_id == Auction.auction_id).order_by(
        Bid.amount.desc(), Bid.bid_date.asc(), Bid.bid_id.asc()
    ).limit(1).correlate(Auction).scalar_subquery()
    leader_amount = select(Bid.amount).where(Bid.bid_id == leader_id).scalar_subquery()
    leader_alias = select(User.alias).join(Bid, Bid.participant_id == User.user_id).where(
        Bid.bid_id == leader_id
    ).scalar_subquery()
    bid_count = select(func.count(Bid.bid_id)).where(Bid.auction_id == Auction.auction_id).scalar_subquery()
    query = select(Auction, Product, Category, User.alias, Status.code, bid_count,
                   leader_amount, leader_alias).join(Status, Auction.status_id == Status.status_id).join(
        Product, Auction.product_id == Product.product_id
    ).join(Category, Product.category_id == Category.category_id).join(
        User, Product.seller_id == User.user_id
    )
    count_query = select(func.count(Auction.auction_id)).join(Status, Auction.status_id == Status.status_id)
    if status:
        query = query.where(Status.code == status)
        count_query = count_query.where(Status.code == status)
    rows = session.execute(query.order_by(Auction.auction_id).limit(limit).offset(offset)).all()
    return rows, session.scalar(count_query) or 0


def get_auction_for_update(session: Session, auction_id: int) -> Auction | None:
    return session.scalar(select(Auction).where(Auction.auction_id == auction_id).with_for_update())
