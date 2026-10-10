from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.auction import Auction
from app.models.auction_cancellation import AuctionCancellation
from app.models.bid import Bid
from app.models.category import Category
from app.models.product import Product
from app.models.status import Status
from app.models.status_history import StatusHistory
from app.models.user import User
from sqlalchemy.orm import aliased


def get_user_for_update(session: Session, user_id: int) -> User | None:
    return session.scalar(select(User).where(User.user_id == user_id).with_for_update())


def list_users(session: Session, *, limit: int, offset: int, search: str | None, status: str | None):
    query = select(User, Status.code).join(Status, User.status_id == Status.status_id)
    count_query = select(func.count(User.user_id)).join(Status, User.status_id == Status.status_id)
    if search:
        term = f"%{search.strip()}%"
        criterion = User.alias.ilike(term) | User.email.ilike(term)
        query = query.where(criterion)
        count_query = count_query.where(criterion)
    if status:
        query = query.where(Status.code == status)
        count_query = count_query.where(Status.code == status)
    rows = session.execute(query.order_by(User.user_id).limit(limit).offset(offset)).all()
    return rows, session.scalar(count_query) or 0


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
    rows = session.execute(query.order_by(Auction.start_date.desc(),Auction.auction_id.desc()).limit(limit).offset(offset)).all()
    return rows, session.scalar(count_query) or 0


def get_auction_for_update(session: Session, auction_id: int) -> Auction | None:
    return session.scalar(select(Auction).where(Auction.auction_id == auction_id).with_for_update())


def get_auction_detail(session: Session, auction_id: int):
    seller = aliased(User)
    cancellation_admin = aliased(User)
    return session.execute(
        select(
            Auction, Product, Category, Status.code,
            seller.alias, seller.name, seller.email, seller.phone_number,
            AuctionCancellation, cancellation_admin.alias,
        )
        .join(Product, Auction.product_id == Product.product_id)
        .join(Category, Product.category_id == Category.category_id)
        .join(seller, Product.seller_id == seller.user_id)
        .join(Status, Auction.status_id == Status.status_id)
        .outerjoin(AuctionCancellation, AuctionCancellation.auction_id == Auction.auction_id)
        .outerjoin(cancellation_admin, AuctionCancellation.admin_user_id == cancellation_admin.user_id)
        .where(Auction.auction_id == auction_id)
    ).first()


def get_auction_leader(session: Session, auction_id: int):
    return session.execute(
        select(Bid, User.alias)
        .join(User, Bid.participant_id == User.user_id)
        .where(Bid.auction_id == auction_id)
        .order_by(Bid.amount.desc(), Bid.bid_date.asc(), Bid.bid_id.asc())
        .limit(1)
    ).first()


def count_auction_bids(session: Session, auction_id: int) -> int:
    return session.scalar(select(func.count(Bid.bid_id)).where(Bid.auction_id == auction_id)) or 0


def list_auction_bids(session: Session, auction_id: int, *, limit: int, offset: int):
    rows = session.execute(
        select(Bid, User.alias, User.name, User.email, User.phone_number)
        .join(User, Bid.participant_id == User.user_id)
        .where(Bid.auction_id == auction_id)
        .order_by(Bid.amount.desc(), Bid.bid_date.asc(), Bid.bid_id.asc())
        .limit(limit).offset(offset)
    ).all()
    total = count_auction_bids(session, auction_id)
    return rows, total


def list_auction_status_history(session: Session, auction_id: int):
    return session.execute(
        select(StatusHistory, User.alias)
        .outerjoin(User, StatusHistory.changed_by == User.user_id)
        .where(StatusHistory.entity_type == "AUCTION", StatusHistory.entity_id == auction_id)
        .order_by(StatusHistory.changed_at.asc(), StatusHistory.history_id.asc())
    ).all()
