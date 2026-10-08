from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import Literal

from app.api.deps import require_role
from app.core.enums import UserRole
from app.db.session import get_db
from app.models.user import User
from app.schemas.auctions import MyAuctionPage, SellerAuctionPage
from app.services import auctions as auction_service

router = APIRouter(prefix="/me", tags=["me"])
MyAuctionStatus = Literal["PROGRAMADA", "ACTIVA", "CERRADA", "FINALIZADA_SIN_GANADOR", "CANCELADA"]


@router.get("/auctions", response_model=MyAuctionPage)
def my_auctions(limit: int = Query(default=20, ge=1, le=100), offset: int = Query(default=0, ge=0),
                status: MyAuctionStatus | None = Query(default=None),
                session: Session = Depends(get_db), participant: User = Depends(require_role(UserRole.POSTOR))) -> MyAuctionPage:
    return auction_service.list_my_auctions(session, participant, limit=limit, offset=offset, status=status)


@router.get("/seller/auctions", response_model=SellerAuctionPage)
def seller_auctions(limit: int = Query(default=20, ge=1, le=100), offset: int = Query(default=0, ge=0),
                    session: Session = Depends(get_db), seller: User = Depends(require_role(UserRole.VENDEDOR))) -> SellerAuctionPage:
    return auction_service.list_seller_auctions(session, seller, limit=limit, offset=offset)
