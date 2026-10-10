from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class UserStatusUpdate(BaseModel):
    status: str = Field(pattern="^(BLOQUEADO|ACTIVO)$")


class AuctionCancelRequest(BaseModel):
    reason: str = Field(min_length=10)

    @field_validator("reason", mode="before")
    @classmethod
    def validate_reason(cls, value: str) -> str:
        value = value.strip()
        if len(value) < 10:
            raise ValueError("El motivo debe contener al menos 10 caracteres.")
        return value


class AdminProductSummary(BaseModel):
    name: str
    brand: str | None
    category: str


class AdminLeaderBid(BaseModel):
    amount: Decimal
    bidder_alias: str


class AdminAuctionItem(BaseModel):
    auction_id: int
    product: AdminProductSummary
    seller_alias: str
    base_price: Decimal
    minimum_increment: Decimal
    start_date: datetime
    end_date: datetime
    status: str
    bid_count: int
    leader_bid: AdminLeaderBid | None


class AdminAuctionPage(BaseModel):
    items: list[AdminAuctionItem]
    limit: int
    offset: int
    total: int


class AdminAuctionDetailProduct(BaseModel):
    name: str
    brand: str | None
    category: str
    description: str


class AdminAuctionSeller(BaseModel):
    alias: str
    name: str
    email: str
    phone_number: str


class AdminAuctionWinner(BaseModel):
    alias: str
    amount: Decimal


class AdminAuctionCancellationDetail(BaseModel):
    reason: str
    cancelled_at: datetime
    admin_alias: str


class AdminAuctionStatusHistoryItem(BaseModel):
    old_status_code: str | None
    new_status_code: str
    event_source: str
    changed_by_alias: str | None
    changed_at: datetime


class AdminAuctionDetail(BaseModel):
    auction_id: int
    product: AdminAuctionDetailProduct
    seller: AdminAuctionSeller
    base_price: Decimal
    minimum_increment: Decimal
    start_date: datetime
    end_date: datetime
    status: str
    bid_count: int
    leader_bid: AdminLeaderBid | None
    winner: AdminAuctionWinner | None
    cancellation: AdminAuctionCancellationDetail | None
    status_history: list[AdminAuctionStatusHistoryItem]


class AdminAuctionBidItem(BaseModel):
    bidder_alias: str
    bidder_name: str
    bidder_email: str
    bidder_phone_number: str
    amount: Decimal
    bid_date: datetime


class AdminAuctionBidPage(BaseModel):
    items: list[AdminAuctionBidItem]
    limit: int
    offset: int
    total: int


class AdminUserStatusResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: int
    status: str


class AdminUserListItem(BaseModel):
    id: int
    alias: str
    role: str
    status: str


class AdminUserPage(BaseModel):
    items: list[AdminUserListItem]
    limit: int
    offset: int
    total: int


class AuctionCancellationResponse(BaseModel):
    auction_id: int
    status: str
    reason: str
    cancelled_at: datetime


class AdminCategoryItem(BaseModel):
    id: int
    name: str
    description: str
    status: str
    product_count: int


class AdminCategoryCreate(BaseModel):
    name: str = Field(min_length=2, max_length=60)
    description: str = Field(max_length=400)

    @field_validator("name", mode="before")
    @classmethod
    def trim_name(cls, value: str) -> str:
        return value.strip()


class AdminCategoryPatch(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=60)
    description: str | None = Field(default=None, max_length=400)

    @field_validator("name", mode="before")
    @classmethod
    def trim_name(cls, value: str | None) -> str | None:
        return value.strip() if isinstance(value, str) else value


class AdminCategoryStatusUpdate(BaseModel):
    status: str = Field(pattern="^(ACTIVA|DESACTIVADA)$")


class AdminCategoryStatusResponse(BaseModel):
    id: int
    status: str
