from datetime import UTC, datetime, timedelta

import jwt
from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.enums import EntityType, UserRole
from app.core.security import hash_password, verify_password
from app.models.user import User
from app.repositories import users as user_repository
from app.repositories import statuses as status_repository
from app.schemas.auth import LoginRequest, RegisterableRole, RegisterRequest, UserResponse

def _public_user(user: User) -> UserResponse:
    return UserResponse(
        user_id=user.user_id,
        role=user.role,
        name=user.name,
        alias=user.alias,
        email=user.email,
    )


def _create_access_token(user: User) -> tuple[str, datetime]:
    if not settings.jwt_secret_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Autenticación no configurada.",
        )
    expires_at = datetime.now(UTC) + timedelta(minutes=settings.access_token_expire_minutes)
    token = jwt.encode(
        {"sub": str(user.user_id), "role": user.role.value, "exp": expires_at},
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )
    return token, expires_at


def register(session: Session, payload: RegisterRequest) -> UserResponse:
    if user_repository.get_by_email(session, str(payload.email)):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="El email ya está registrado.")
    if user_repository.get_by_alias(session, payload.alias):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="El alias ya está registrado.")
    if payload.role == RegisterableRole.POSTOR and not payload.accept_bid_policy:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="El Postor debe aceptar la política de pujas.",
        )

    active_status = status_repository.get_status_for_entity(
        session, "ACTIVO", EntityType.USER.value
    )
    if active_status is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="El catálogo de estados no está inicializado.",
        )

    accepted_at = datetime.now(UTC) if payload.role == RegisterableRole.POSTOR else None
    user = User(
        status_id=active_status.status_id,
        role=UserRole(payload.role.value),
        name=payload.name,
        alias=payload.alias,
        email=str(payload.email),
        password_hash=hash_password(payload.password),
        phone_number=payload.phone_number,
        address=payload.address,
        bid_policy_accepted_at=accepted_at,
    )
    user_repository.add_user(session, user)
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El email o el alias ya está registrado.",
        ) from None
    session.refresh(user)
    return _public_user(user)


def login(session: Session, payload: LoginRequest) -> tuple[str, datetime, UserResponse]:
    user = user_repository.get_by_email(session, str(payload.email))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    account_status = status_repository.get_status_code(session, user.status_id)
    if account_status in {"BLOQUEADO", "DESACTIVADO"}:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token, expires_at = _create_access_token(user)
    return token, expires_at, _public_user(user)
