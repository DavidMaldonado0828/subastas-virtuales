from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.auction import Auction
from app.models.bid import Bid
from app.models.product import Product
from app.models.status import Status


def get_status_for_auction(session: Session, code: str) -> Status | None:
    from app.models.status import StatusApplicability

    return session.scalar(select(Status).join(StatusApplicability).where(
        Status.code == code, StatusApplicability.entity_type == "AUCTION", Status.enabled.is_(True)
    ))


def get_product(session: Session, product_id: int) -> Product | None:
    return session.get(Product, product_id)


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


def has_bids(session: Session, auction_id: int) -> bool:
    return bool(session.scalar(select(Bid.bid_id).where(Bid.auction_id == auction_id).limit(1)))
