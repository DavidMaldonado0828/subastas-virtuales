from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import require_role
from app.core.enums import UserRole
from app.db.session import get_db
from app.models.user import User
from app.schemas.auctions import AuctionCreate, AuctionPatch, AuctionResponse
from app.services import auctions as auction_service

router = APIRouter(prefix="/auctions", tags=["auctions"])


@router.post("", response_model=AuctionResponse, status_code=status.HTTP_201_CREATED)
def create_auction(
    payload: AuctionCreate,
    session: Session = Depends(get_db),
    seller: User = Depends(require_role(UserRole.VENDEDOR)),
) -> AuctionResponse:
    return auction_service.create(session, seller, payload)


@router.patch("/{auction_id}", response_model=AuctionResponse)
def update_auction(
    auction_id: int,
    payload: AuctionPatch,
    session: Session = Depends(get_db),
    seller: User = Depends(require_role(UserRole.VENDEDOR)),
) -> AuctionResponse:
    return auction_service.update(session, seller, auction_id, payload)
