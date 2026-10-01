from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class AuctionCreate(BaseModel):
    product_id: int = Field(gt=0)
    base_price: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    minimum_increment: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    start_date: datetime
    end_date: datetime


class AuctionPatch(BaseModel):
    base_price: Decimal | None = Field(default=None, gt=0, max_digits=12, decimal_places=2)
    minimum_increment: Decimal | None = Field(default=None, gt=0, max_digits=12, decimal_places=2)
    start_date: datetime | None = None
    end_date: datetime | None = None


class AuctionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    auction_id: int
    product_id: int
    status_id: int
    base_price: Decimal = Field(max_digits=12, decimal_places=2)
    minimum_increment: Decimal = Field(max_digits=12, decimal_places=2)
    start_date: datetime
    end_date: datetime
    created_at: datetime
    updated_at: datetime | None
