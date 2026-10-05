from datetime import UTC, datetime

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.enums import UserRole
from app.models.auction_cancellation import AuctionCancellation
from app.models.user import User
from app.repositories import admin as admin_repository
from app.repositories import auctions as auction_repository
from app.repositories import statuses as status_repository
from app.schemas.admin import (AdminAuctionItem, AdminAuctionPage, AdminLeaderBid, AdminUserListItem,
    AdminUserPage,
    AdminProductSummary, AuctionCancellationResponse, AuctionCancelRequest, UserStatusUpdate)
from app.services.status_history import record_status_change

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

#Lista los usuarios con paginación y filtrado por estado, devolviendo un objeto que contiene los detalles de cada usuario y la información de paginación.
def list_users(session: Session, *, limit: int, offset: int, search: str | None, status: str | None) -> AdminUserPage:
    rows, total = admin_repository.list_users(
        session, limit=limit, offset=offset, search=search, status=status
    )
    items = [AdminUserListItem(id=user.user_id, alias=user.alias, role=user.role.value, status=status_code)
             for user, status_code in rows]
    return AdminUserPage(items=items, limit=limit, offset=offset, total=total)
