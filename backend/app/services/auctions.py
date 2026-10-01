from datetime import UTC, datetime
from decimal import Decimal

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.auction import Auction
from app.models.user import User
from app.repositories import auctions as auction_repository
from app.repositories import bids as bid_repository
from app.repositories import statuses as status_repository
from app.schemas.auctions import AuctionCreate, AuctionPatch
from app.schemas.auctions import AuctionCatalogItem, AuctionCatalogPage, AuctionPublicDetail, LeaderBid, PublicProduct
from app.services.status_history import record_status_change


def _input_utc(value: datetime, field: str) -> datetime:
    if value.tzinfo is None or value.utcoffset() is None:
        raise HTTPException(status_code=422, detail=f"{field} debe incluir zona horaria.")
    return value.astimezone(UTC)


def _stored_utc(value: datetime) -> datetime:
    # SQLite test databases return naive values for timezone-aware columns.
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


def calculate_status(start_date: datetime, end_date: datetime, now: datetime) -> str:
    """Return the temporal auction state shared by reads and the scheduler."""
    start = _stored_utc(start_date)
    end = _stored_utc(end_date)
    current = _stored_utc(now)
    if current >= end:
        return "CERRADA"
    if current >= start:
        return "ACTIVA"
    return "PROGRAMADA"


def _public_product(product, category) -> PublicProduct:
    return PublicProduct(product_id=product.product_id, name=product.name,
        brand=product.brand, image_url=product.image_url, category=category.name)


def _catalog_item(row, now: datetime) -> AuctionCatalogItem:
    auction, product, category, seller_alias, leader_amount, _leader_alias = row
    return AuctionCatalogItem(
        id=auction.auction_id,
        product=_public_product(product, category),
        base_price=auction.base_price,
        minimum_increment=auction.minimum_increment,
        start_date=auction.start_date,
        end_date=auction.end_date,
        status=calculate_status(auction.start_date, auction.end_date, now),
        current_leader_amount=leader_amount,
        seller_alias=seller_alias,
    )


def list_public(session: Session, *, limit: int, offset: int) -> AuctionCatalogPage:
    now = datetime.now(UTC)
    rows = auction_repository.public_rows(session, limit=limit, offset=offset)
    return AuctionCatalogPage(items=[_catalog_item(row, now) for row in rows], limit=limit, offset=offset)


def get_public(session: Session, auction_id: int) -> AuctionPublicDetail:
    rows = auction_repository.public_rows(session, limit=1, offset=0, auction_id=auction_id)
    if not rows:
        raise HTTPException(status_code=404, detail="Subasta no encontrada.")
    row = rows[0]
    now = datetime.now(UTC)
    item = _catalog_item(row, now)
    auction, _product, _category, _seller_alias, leader_amount, leader_alias = row
    if item.status == "PROGRAMADA":
        remaining = max(0, int((_stored_utc(auction.start_date) - now).total_seconds()))
    elif item.status == "ACTIVA":
        remaining = max(0, int((_stored_utc(auction.end_date) - now).total_seconds()))
    else:
        remaining = 0
    leader = LeaderBid(amount=leader_amount, bidder_alias=leader_alias) if leader_amount is not None else None
    return AuctionPublicDetail(**item.model_dump(), leader_bid=leader, remaining_seconds=remaining)


def _validate_values(base_price: Decimal, increment: Decimal, start: datetime, end: datetime) -> None:
    now = datetime.now(UTC)
    if base_price <= 0:
        raise HTTPException(status_code=422, detail="base_price debe ser mayor que cero.")
    if increment <= 0:
        raise HTTPException(status_code=422, detail="minimum_increment debe ser mayor que cero.")
    if start <= now:
        raise HTTPException(status_code=422, detail="start_date debe ser futura.")
    if end <= start:
        raise HTTPException(status_code=422, detail="end_date debe ser posterior a start_date.")


def create(session: Session, seller: User, payload: AuctionCreate) -> Auction:
    product = auction_repository.get_product(session, payload.product_id)
    if product is None or product.seller_id != seller.user_id:
        raise HTTPException(status_code=404, detail="Producto no encontrado.")
    if status_repository.get_status_code(session, product.status_id) != "ACTIVO":
        raise HTTPException(status_code=409, detail="El producto debe estar ACTIVO para crear una subasta.")
    if auction_repository.has_scheduled_or_active_auction(session, product.product_id):
        raise HTTPException(status_code=409, detail="El producto ya tiene una subasta PROGRAMADA o ACTIVA.")

    start = _input_utc(payload.start_date, "start_date")
    end = _input_utc(payload.end_date, "end_date")
    _validate_values(payload.base_price, payload.minimum_increment, start, end)
    scheduled = auction_repository.get_status_for_auction(session, "PROGRAMADA")
    if scheduled is None:
        raise HTTPException(status_code=503, detail="El estado PROGRAMADA no está disponible.")
    auction = Auction(
        product_id=product.product_id,
        status_id=scheduled.status_id,
        base_price=payload.base_price,
        minimum_increment=payload.minimum_increment,
        start_date=start,
        end_date=end,
    )
    auction_repository.add(session, auction)
    session.flush()
    record_status_change(
        session,
        entity_type="AUCTION",
        entity_id=auction.auction_id,
        old_status_code=None,
        new_status_code="PROGRAMADA",
        changed_by=seller,
        event_source="API_CREATE_AUCTION",
    )
    session.commit()
    session.refresh(auction)
    return auction


def update(session: Session, seller: User, auction_id: int, payload: AuctionPatch) -> Auction:
    auction = auction_repository.get_owned(session, auction_id, seller.user_id)
    if auction is None:
        raise HTTPException(status_code=404, detail="Subasta no encontrada.")
    if bid_repository.exists_for_auction(session, auction_id):
        raise HTTPException(status_code=409, detail="No se puede modificar la subasta porque ya tiene pujas registradas.")
    changes = payload.model_dump(exclude_unset=True)
    if not changes:
        raise HTTPException(status_code=422, detail="Debe indicar al menos un campo para actualizar.")
    for field, value in changes.items():
        if value is None:
            raise HTTPException(status_code=422, detail=f"{field} no puede ser nulo.")
    start = _input_utc(changes["start_date"], "start_date") if "start_date" in changes else _stored_utc(auction.start_date)
    end = _input_utc(changes["end_date"], "end_date") if "end_date" in changes else _stored_utc(auction.end_date)
    base_price = changes.get("base_price", auction.base_price)
    increment = changes.get("minimum_increment", auction.minimum_increment)
    _validate_values(base_price, increment, start, end)
    for field, value in changes.items():
        setattr(auction, field, value)
    auction.start_date = start
    auction.end_date = end
    auction.updated_at = datetime.now(UTC)
    session.commit()
    session.refresh(auction)
    return auction
