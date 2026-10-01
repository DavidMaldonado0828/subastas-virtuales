from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


def _required_text(value: str | None) -> str | None:
    if value is None:
        return None
    value = value.strip()
    if not value:
        raise ValueError("El campo no puede estar vacío.")
    return value


class ProductCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    description: str = Field(min_length=1, max_length=400)
    category_id: int = Field(gt=0)
    brand: str | None = None
    image_url: str | None = Field(default=None, max_length=500)

    _clean_name = field_validator("name")(_required_text)
    _clean_description = field_validator("description")(_required_text)


class ProductPatch(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    description: str | None = Field(default=None, min_length=1, max_length=400)
    category_id: int | None = Field(default=None, gt=0)
    brand: str | None = None
    image_url: str | None = Field(default=None, max_length=500)

    _clean_name = field_validator("name")(_required_text)
    _clean_description = field_validator("description")(_required_text)


class ProductResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    product_id: int
    seller_id: int
    category_id: int
    status_id: int
    name: str
    brand: str | None
    description: str
    image_url: str | None
    created_at: datetime
    updated_at: datetime | None


class CategoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    category_id: int
    name: str
    description: str


class ProductDeleteResponse(BaseModel):
    product_id: int
    result: str
    status: str | None
