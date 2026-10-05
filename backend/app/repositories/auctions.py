from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.auction import Auction
from app.models.bid import Bid
from app.models.product import Product
from app.models.status import Status
from app.models.category import Category
from app.models.user import User


def get_status_for_auction(session: Session, code: str) -> Status | None:
    from app.models.status import StatusApplicability

    return session.scalar(select(Status).join(StatusApplicability).where(
        Status.code == code, StatusApplicability.entity_type == "AUCTION", Status.enabled.is_(True)
    ))


def get_product(session: Session, product_id: int) -> Product | None:
    return session.get(Product, product_id)


def get_by_id(session: Session, auction_id: int) -> Auction | None:
    return session.get(Auction, auction_id)


def get_status_code(session: Session, status_id: int) -> str | None:
    return session.scalar(select(Status.code).where(Status.status_id == status_id))


def has_scheduled_or_active_auction(session: Session, product_id: int) -> bool:
    return bool(session.scalar(select(Auction.auction_id).join(Status).where(
        Auction.product_id == product_id, Status.code.in_(("PROGRAMADA", "ACTIVA"))
    ).limit(1)))


def add(session: Session, auction: Auction) -> Auction:
    session.add(auction)
    return auction


def get_owned(session: Session, auction_id: int, seller_id: int) -> Auction | None:
    return session.scalar(select(Auction).join(Product).where(
        Auction.auction_id == auction_id, Product.seller_id == seller_id
    ))


def get_seller_id(session: Session, auction_id: int) -> int | None:
    return session.scalar(select(Product.seller_id).join(Auction, Auction.product_id == Product.product_id)
        .where(Auction.auction_id == auction_id))


def has_bids(session: Session, auction_id: int) -> bool:
    return bool(session.scalar(select(Bid.bid_id).where(Bid.auction_id == auction_id).limit(1)))


def public_rows(session: Session, *, limit: int, offset: int, auction_id: int | None = None):
    leader = select(Bid.bid_id).where(Bid.auction_id == Auction.auction_id).order_by(
        Bid.amount.desc(), Bid.bid_date.asc(), Bid.bid_id.asc()
    ).limit(1).correlate(Auction).scalar_subquery()
    leader_amount = select(Bid.amount).where(Bid.bid_id == leader).scalar_subquery()
    leader_alias = select(User.alias).join(Bid, Bid.participant_id == User.user_id).where(
        Bid.bid_id == leader
    ).scalar_subquery()
    query = select(Auction, Product, Category, User.alias, leader_amount, leader_alias).join(
        Status, Auction.status_id == Status.status_id
    ).join(Product, Auction.product_id == Product.product_id).join(
        Category, Product.category_id == Category.category_id
    ).join(User, Product.seller_id == User.user_id).where(
        Status.code.in_(("PROGRAMADA", "ACTIVA", "CERRADA", "FINALIZADA_SIN_GANADOR"))
    )
    if auction_id is not None:
        query = query.where(Auction.auction_id == auction_id)
    else:
        query = query.order_by(Auction.auction_id).limit(limit).offset(offset)
    return list(session.execute(query))


def get_status_ids(session: Session) -> dict[str, int]:
    from app.models.status import StatusApplicability

    rows = session.execute(select(Status.code, Status.status_id).join(StatusApplicability).where(
        StatusApplicability.entity_type == "AUCTION", Status.enabled.is_(True),
        Status.code.in_(("PROGRAMADA", "ACTIVA", "CERRADA", "FINALIZADA_SIN_GANADOR")),
    ))
    return {code: status_id for code, status_id in rows}


def open_for_scheduling(session: Session, *, for_update: bool = False) -> list[Auction]:
    query = select(Auction).join(Status, Auction.status_id == Status.status_id).where(
        Status.code.in_(("PROGRAMADA", "ACTIVA"))
    ).order_by(Auction.auction_id)
    if for_update:
        query = query.with_for_update()
    return list(session.scalars(query))


def list_seller_auctions(session: Session, seller_id: int, *, limit: int, offset: int):
    bid_count = select(func.count(Bid.bid_id)).where(Bid.auction_id == Auction.auction_id).scalar_subquery()
    query = select(Auction, Product, Category, Status.code, bid_count).join(
        Product, Auction.product_id == Product.product_id
    ).join(Category, Product.category_id == Category.category_id).join(
        Status, Auction.status_id == Status.status_id
    ).where(Product.seller_id == seller_id)
    count_query = select(func.count(Auction.auction_id)).join(
        Product, Auction.product_id == Product.product_id
    ).where(Product.seller_id == seller_id)
    rows = session.execute(query.order_by(Auction.auction_id).limit(limit).offset(offset)).all()
    return rows, session.scalar(count_query) or 0
