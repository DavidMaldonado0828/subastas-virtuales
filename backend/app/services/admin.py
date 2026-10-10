from datetime import UTC, datetime

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.enums import UserRole
from app.models.auction import Auction
from app.models.auction_cancellation import AuctionCancellation
from app.models.category import Category
from app.models.user import User
from app.repositories import admin as admin_repository
from app.repositories import auctions as auction_repository
from app.repositories import categories as category_repository
from app.repositories import statuses as status_repository
from app.schemas.admin import (AdminAuctionBidItem, AdminAuctionBidPage, AdminAuctionCancellationDetail,
    AdminAuctionDetail, AdminAuctionDetailProduct, AdminAuctionItem, AdminAuctionPage, AdminAuctionSeller,
    AdminAuctionStatusHistoryItem, AdminAuctionWinner, AdminLeaderBid, AdminUserListItem, AdminUserPage,
    AdminProductSummary, AuctionCancellationResponse, AuctionCancelRequest, UserStatusUpdate)
from app.schemas.admin import (AdminCategoryCreate, AdminCategoryItem, AdminCategoryPatch,
    AdminCategoryStatusResponse, AdminCategoryStatusUpdate)
from app.services.status_history import record_status_change


def _category_status_for_api(code: str) -> str:
    return "DESACTIVADA" if code == "DESACTIVADO" else "ACTIVA"


def list_categories(session: Session) -> list[AdminCategoryItem]:
    return [AdminCategoryItem(id=category.category_id, name=category.name,
        description=category.description, status=_category_status_for_api(status),
        product_count=count)
        for category, status, count in category_repository.list_admin(session)]


def create_category(session: Session, admin: User, payload: AdminCategoryCreate) -> AdminCategoryItem:
    name = payload.name.strip()
    if category_repository.name_exists_normalized(session, name):
        raise HTTPException(status_code=409, detail="Ya existe una categoría con ese nombre.")
    active = status_repository.get_status_for_entity(session, "ACTIVO", "CATEGORY")
    if active is None:
        raise HTTPException(status_code=503, detail="Estado ACTIVO de categoría no disponible.")
    try:
        category = Category(name=name, description=payload.description, status_id=active.status_id)
        category_repository.add(session, category)
        session.flush()
        record_status_change(session, entity_type="CATEGORY", entity_id=category.category_id,
            old_status_code=None, new_status_code="ACTIVO", changed_by=admin, event_source="ADMIN")
        session.commit()
        session.refresh(category)
        return AdminCategoryItem(id=category.category_id, name=category.name,
            description=category.description, status="ACTIVA", product_count=0)
    except Exception:
        session.rollback()
        raise


def update_category(session: Session, category_id: int, payload: AdminCategoryPatch) -> AdminCategoryItem:
    changes = payload.model_dump(exclude_unset=True)
    if not changes:
        raise HTTPException(status_code=422, detail="Debe indicar al menos un campo.")
    if any(value is None for value in changes.values()):
        raise HTTPException(status_code=422, detail="Los campos enviados no pueden ser nulos.")
    try:
        category = category_repository.get_for_update(session, category_id)
        if category is None:
            raise HTTPException(status_code=404, detail="Categoría no encontrada.")
        if "name" in changes:
            changes["name"] = changes["name"].strip()
            if category_repository.name_exists_normalized(session, changes["name"], exclude_id=category_id):
                raise HTTPException(status_code=409, detail="Ya existe una categoría con ese nombre.")
        for field, value in changes.items():
            setattr(category, field, value)
        category.updated_at = datetime.now(UTC)
        session.commit()
        session.refresh(category)
        code = status_repository.get_status_code(session, category.status_id) or "ACTIVO"
        count = category_repository.list_admin(session)
        product_count = next((n for row, _s, n in count if row.category_id == category_id), 0)
        return AdminCategoryItem(id=category.category_id, name=category.name,
            description=category.description, status=_category_status_for_api(code), product_count=product_count)
    except Exception:
        session.rollback()
        raise


def update_category_status(session: Session, admin: User, category_id: int,
                           payload: AdminCategoryStatusUpdate) -> AdminCategoryStatusResponse:
    requested_code = "DESACTIVADO" if payload.status == "DESACTIVADA" else "ACTIVO"
    try:
        category = category_repository.get_for_update(session, category_id)
        if category is None:
            raise HTTPException(status_code=404, detail="Categoría no encontrada.")
        current = status_repository.get_status_code(session, category.status_id)
        if current == requested_code:
            raise HTTPException(status_code=409, detail="La categoría ya tiene ese estado.")
        target = status_repository.get_status_for_entity(session, requested_code, "CATEGORY")
        if target is None:
            raise HTTPException(status_code=503, detail="Estado de categoría no disponible.")
        category.status_id = target.status_id
        category.updated_at = datetime.now(UTC)
        record_status_change(session, entity_type="CATEGORY", entity_id=category_id,
            old_status_code=current, new_status_code=requested_code, changed_by=admin,
            event_source="ADMIN")
        session.commit()
        return AdminCategoryStatusResponse(id=category_id, status=payload.status)
    except Exception:
        session.rollback()
        raise

#Función para actualizar el estado de un usuario por parte de un administrador.
def update_user_status(session: Session, admin: User, user_id: int, payload: UserStatusUpdate):
    if admin.user_id == user_id:
        raise HTTPException(status_code=409, detail="No puede cambiar su propio estado.")
    user = admin_repository.get_user_for_update(session, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="Usuario no encontrado.")
    if payload.status == "BLOQUEADO" and user.role == UserRole.ADMIN:
        raise HTTPException(status_code=409, detail="No se puede bloquear una cuenta ADMIN.")
    current = status_repository.get_status_code(session, user.status_id)
    if current not in {"ACTIVO", "BLOQUEADO"}:
        raise HTTPException(status_code=409, detail="Solo se pueden cambiar estados ACTIVO o BLOQUEADO.")
    if current == payload.status:
        raise HTTPException(status_code=409, detail="El usuario ya tiene ese estado.")
    target = status_repository.get_status_for_entity(session, payload.status, "USER")
    if target is None:
        raise HTTPException(status_code=503, detail="Estado de usuario no disponible.")
    try:
        user.status_id = target.status_id
        user.updated_at = datetime.now(UTC)
        record_status_change(session, entity_type="USER", entity_id=user.user_id,
            old_status_code=current, new_status_code=payload.status, changed_by=admin,
            event_source="ADMIN")
        session.commit()
        session.refresh(user)
        return {"user_id": user.user_id, "status": payload.status}
    except Exception:
        session.rollback()
        raise

#Función para cancelar una subasta por parte de un administrador, registrando la razón de la cancelación y actualizando el historial de estados.
def cancel_auction(session: Session, admin: User, auction_id: int, payload: AuctionCancelRequest):
    try:
        auction = admin_repository.get_auction_for_update(session, auction_id)
        if auction is None:
            raise HTTPException(status_code=404, detail="Subasta no encontrada.")
        current = auction_repository.get_status_code(session, auction.status_id)
        if current not in {"PROGRAMADA", "ACTIVA"}:
            raise HTTPException(status_code=409, detail="Solo se pueden cancelar subastas PROGRAMADA o ACTIVA.")
        target = auction_repository.get_status_for_auction(session, "CANCELADA")
        if target is None:
            raise HTTPException(status_code=503, detail="Estado CANCELADA no disponible.")
        cancelled_at = datetime.now(UTC)
        auction.status_id = target.status_id
        auction.updated_at = cancelled_at
        cancellation = AuctionCancellation(auction_id=auction_id, admin_user_id=admin.user_id,
            reason_detail={"reason": payload.reason.strip()}, cancelled_at=cancelled_at)
        session.add(cancellation)
        record_status_change(session, entity_type="AUCTION", entity_id=auction_id,
            old_status_code=current, new_status_code="CANCELADA", changed_by=admin,
            event_source="ADMIN")
        session.commit()
        return AuctionCancellationResponse(auction_id=auction_id, status="CANCELADA",
            reason=payload.reason.strip(), cancelled_at=cancelled_at)
    except Exception:
        session.rollback()
        raise

#Lista las subastas con paginación y filtrado por estado, devolviendo un objeto que contiene los detalles de cada subasta y la información de paginación.
def list_auctions(session: Session, *, limit: int, offset: int, status: str | None) -> AdminAuctionPage:
    rows, total = admin_repository.list_auctions(session, limit=limit, offset=offset, status=status)
    items = [AdminAuctionItem(
        auction_id=auction.auction_id,
        product=AdminProductSummary(name=product.name, brand=product.brand, category=category.name),
        seller_alias=seller_alias,
        base_price=auction.base_price,
        minimum_increment=auction.minimum_increment,
        start_date=auction.start_date,
        end_date=auction.end_date,
        status=status_code,
        bid_count=bid_count,
        leader_bid=AdminLeaderBid(amount=leader_amount, bidder_alias=leader_alias)
            if leader_amount is not None else None,
    ) for auction, product, category, seller_alias, status_code, bid_count, leader_amount, leader_alias in rows]
    return AdminAuctionPage(items=items, limit=limit, offset=offset, total=total)


def get_auction_detail(session: Session, auction_id: int) -> AdminAuctionDetail:
    row = admin_repository.get_auction_detail(session, auction_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Subasta no encontrada.")

    (auction, product, category, status_code, seller_alias, seller_name, seller_email,
     seller_phone, cancellation, cancellation_admin_alias) = row
    leader_row = admin_repository.get_auction_leader(session, auction_id)
    leader = AdminLeaderBid(amount=leader_row[0].amount, bidder_alias=leader_row[1]) if leader_row else None
    winner = AdminAuctionWinner(alias=leader.bidder_alias, amount=leader.amount) \
        if status_code == "CERRADA" and leader is not None else None

    cancellation_detail = None
    if cancellation is not None:
        reason_detail = cancellation.reason_detail
        reason = reason_detail.get("reason", "") if isinstance(reason_detail, dict) else str(reason_detail)
        cancellation_detail = AdminAuctionCancellationDetail(
            reason=reason,
            cancelled_at=cancellation.cancelled_at,
            admin_alias=cancellation_admin_alias,
        )

    history = [AdminAuctionStatusHistoryItem(
        old_status_code=event.old_status_code,
        new_status_code=event.new_status_code,
        event_source=event.event_source,
        changed_by_alias=changed_by_alias,
        changed_at=event.changed_at,
    ) for event, changed_by_alias in admin_repository.list_auction_status_history(session, auction_id)]

    return AdminAuctionDetail(
        auction_id=auction.auction_id,
        product=AdminAuctionDetailProduct(
            name=product.name, brand=product.brand, category=category.name, description=product.description,
        ),
        seller=AdminAuctionSeller(
            alias=seller_alias, name=seller_name, email=seller_email, phone_number=seller_phone,
        ),
        base_price=auction.base_price,
        minimum_increment=auction.minimum_increment,
        start_date=auction.start_date,
        end_date=auction.end_date,
        status=status_code,
        bid_count=admin_repository.count_auction_bids(session, auction_id),
        leader_bid=leader,
        winner=winner,
        cancellation=cancellation_detail,
        status_history=history,
    )


def list_auction_bids(session: Session, auction_id: int, *, limit: int, offset: int) -> AdminAuctionBidPage:
    if session.get(Auction, auction_id) is None:
        raise HTTPException(status_code=404, detail="Subasta no encontrada.")
    rows, total = admin_repository.list_auction_bids(session, auction_id, limit=limit, offset=offset)
    items = [AdminAuctionBidItem(
        bidder_alias=alias,
        bidder_name=name,
        bidder_email=email,
        bidder_phone_number=phone_number,
        amount=bid.amount,
        bid_date=bid.bid_date,
    ) for bid, alias, name, email, phone_number in rows]
    return AdminAuctionBidPage(items=items, limit=limit, offset=offset, total=total)

#Lista los usuarios con paginación y filtrado por estado, devolviendo un objeto que contiene los detalles de cada usuario y la información de paginación.
def list_users(session: Session, *, limit: int, offset: int, search: str | None, status: str | None) -> AdminUserPage:
    rows, total = admin_repository.list_users(
        session, limit=limit, offset=offset, search=search, status=status
    )
    items = [AdminUserListItem(id=user.user_id, alias=user.alias, role=user.role.value, status=status_code)
             for user, status_code in rows]
    return AdminUserPage(items=items, limit=limit, offset=offset, total=total)
