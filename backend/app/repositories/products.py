from sqlalchemy import exists, select
from sqlalchemy.orm import Session

from app.models.auction import Auction
from app.models.product import Product
from app.models.status import Status
from app.models.status_history import StatusHistory


def add(session: Session, product: Product) -> Product:
    session.add(product)
    return product


def get_owned(session: Session, product_id: int, seller_id: int) -> Product | None:
    return session.scalar(select(Product).where(
        Product.product_id == product_id, Product.seller_id == seller_id
    ))


def list_owned(session: Session, seller_id: int, brand: str | None, category_id: int | None, name: str | None) -> list[Product]:
    query = select(Product).where(Product.seller_id == seller_id)
    if brand:
        query = query.where(Product.brand.ilike(f"%{brand}%"))
    if category_id is not None:
        query = query.where(Product.category_id == category_id)
    if name:
        query = query.where(Product.name.ilike(f"%{name}%"))
    return list(session.scalars(query.order_by(Product.product_id)))


def has_auctions(session: Session, product_id: int) -> bool:
    return bool(session.scalar(select(exists().where(Auction.product_id == product_id))))


def get_auctions(session: Session, product_id: int) -> list[Auction]:
    return list(session.scalars(select(Auction).where(Auction.product_id == product_id)))


def ever_active_or_closed(session: Session, product_id: int) -> bool:
    auction_ids = select(Auction.auction_id).where(Auction.product_id == product_id)
    current = session.scalar(select(exists().where(
        Auction.product_id == product_id,
        Auction.status_id.in_(select(Status.status_id).where(Status.code.in_(("ACTIVA", "CERRADA"))))
    )))
    historical = session.scalar(select(exists().where(
        StatusHistory.entity_type == "AUCTION",
        StatusHistory.entity_id.in_(auction_ids),
        StatusHistory.new_status_code.in_(("ACTIVA", "CERRADA")),
    )))
    return bool(current or historical)
