from datetime import datetime
from enum import Enum

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.core.enums import UserRole


class RegisterableRole(str, Enum):
    VENDEDOR = UserRole.VENDEDOR.value
    POSTOR = UserRole.POSTOR.value


class RegisterRequest(BaseModel):
    role: RegisterableRole
    name: str = Field(min_length=1, max_length=100)
    alias: str = Field(min_length=1, max_length=50)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    phone_number: str = Field(min_length=1, max_length=20)
    address: str | None = Field(default=None, max_length=200)
    accept_bid_policy: bool = False

    @field_validator("name", "alias", "phone_number")
    @classmethod
    def trim_required_text(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("El campo no puede estar vacío.")
        return cleaned

    @field_validator("address")
    @classmethod
    def trim_optional_address(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        return cleaned or None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class UserResponse(BaseModel):
    user_id: int
    role: UserRole
    name: str
    alias: str
    email: EmailStr


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_at: datetime
    user: UserResponse
