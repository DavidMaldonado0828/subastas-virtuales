from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.auth import AuthResponse, LoginRequest, RegisterRequest, UserResponse
from app.services import auth as auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest, session: Session = Depends(get_db)) -> UserResponse:
    return auth_service.register(session, payload)


@router.post("/login", response_model=AuthResponse)
def login(payload: LoginRequest, session: Session = Depends(get_db)) -> AuthResponse:
    token, expires_at, user = auth_service.login(session, payload)
    return AuthResponse(access_token=token, expires_at=expires_at, user=user)
