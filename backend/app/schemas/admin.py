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
