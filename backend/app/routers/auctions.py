from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_optional_current_user, require_role
from app.core.enums import UserRole
from app.db.session import get_db
from app.models.user import User
from app.schemas.auctions import AuctionCatalogPage, AuctionCreate, AuctionPatch, AuctionPublicDetail, AuctionResponse, BidCreate, BidResponse, MyAuctionPage, BidHistoryPage
from app.services import auctions as auction_service

router = APIRouter(prefix="/auctions", tags=["auctions"])


@router.get("", response_model=AuctionCatalogPage)
def public_auction_catalog(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    session: Session = Depends(get_db),
) -> AuctionCatalogPage:
    return auction_service.list_public(session, limit=limit, offset=offset)


@router.get("/{auction_id}", response_model=AuctionPublicDetail)
def public_auction_detail(auction_id: int, session: Session = Depends(get_db)) -> AuctionPublicDetail:
    return auction_service.get_public(session, auction_id)


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


@router.post("/{auction_id}/bids", response_model=BidResponse, status_code=status.HTTP_201_CREATED)
def place_bid(auction_id: int, payload: BidCreate, session: Session = Depends(get_db),
              participant: User = Depends(require_role(UserRole.POSTOR))) -> BidResponse:
    return auction_service.place_bid(session, participant, auction_id, payload)


@router.get("/{auction_id}/bids", response_model=BidHistoryPage)
def bid_history(
    auction_id: int,
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    session: Session = Depends(get_db),
    current_user: User | None = Depends(get_optional_current_user),
) -> BidHistoryPage:
    return auction_service.list_bid_history(session, auction_id, current_user, limit=limit, offset=offset)
