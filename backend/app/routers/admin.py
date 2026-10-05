from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.deps import require_role
from app.core.enums import UserRole
from app.db.session import get_db
from app.models.user import User
from app.schemas.admin import (AdminAuctionPage, AdminUserPage, AdminUserStatusResponse,
    AuctionCancellationResponse, AuctionCancelRequest, UserStatusUpdate)
from app.services import admin as admin_service

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/users", response_model=AdminUserPage)
def list_users(limit: int = Query(default=20, ge=1, le=100), offset: int = Query(default=0, ge=0),
               search: str | None = Query(default=None, min_length=1),
               status: str | None = Query(default=None), session: Session = Depends(get_db),
               admin: User = Depends(require_role(UserRole.ADMIN))):
    if status is not None and status not in {"ACTIVO", "BLOQUEADO", "DESACTIVADO"}:
        raise HTTPException(status_code=422, detail="Estado de usuario inválido.")
    return admin_service.list_users(session, limit=limit, offset=offset, search=search, status=status)


@router.patch("/users/{user_id}/status", response_model=AdminUserStatusResponse)
def update_user_status(user_id: int, payload: UserStatusUpdate,
                       session: Session = Depends(get_db), admin: User = Depends(require_role(UserRole.ADMIN))):
    return admin_service.update_user_status(session, admin, user_id, payload)


@router.post("/auctions/{auction_id}/cancel", response_model=AuctionCancellationResponse)
def cancel_auction(auction_id: int, payload: AuctionCancelRequest,
                   session: Session = Depends(get_db), admin: User = Depends(require_role(UserRole.ADMIN))):
    return admin_service.cancel_auction(session, admin, auction_id, payload)


@router.get("/auctions", response_model=AdminAuctionPage)
def list_auctions(limit: int = Query(default=20, ge=1, le=100), offset: int = Query(default=0, ge=0),
                  status: str | None = Query(default=None), session: Session = Depends(get_db),
                  admin: User = Depends(require_role(UserRole.ADMIN))):
    if status is not None and status not in {"PROGRAMADA", "ACTIVA", "CERRADA", "FINALIZADA_SIN_GANADOR", "CANCELADA"}:
        raise HTTPException(status_code=422, detail="Estado de subasta inválido.")
    return admin_service.list_auctions(session, limit=limit, offset=offset, status=status)
