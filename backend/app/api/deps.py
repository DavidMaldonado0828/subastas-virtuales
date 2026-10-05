from collections.abc import Callable

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.enums import UserRole
from app.db.session import get_db
from app.models.user import User
from app.repositories import users as user_repository
from app.repositories import statuses as status_repository

bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    session: Session = Depends(get_db),
) -> User:
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Credenciales inválidas o token expirado.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credentials is None:
        raise unauthorized
    if not settings.jwt_secret_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Autenticación no configurada.",
        )
    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
            options={"require": ["sub", "exp"]},
        )
        user_id = int(payload["sub"])
    except (jwt.InvalidTokenError, KeyError, TypeError, ValueError):
        raise unauthorized from None

    user = user_repository.get_by_id(session, user_id)
    if user is None:
        raise unauthorized
    current_status = status_repository.get_status_code(session, user.status_id)
    if current_status == "BLOQUEADO":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
            detail="Su cuenta est\u00e1 bloqueada. Contacte al administrador.")
    if current_status == "DESACTIVADO":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
            detail="Su cuenta est\u00e1 desactivada.")
    if current_status in {"BLOQUEADO", "DESACTIVADO"}:
        raise unauthorized
    return user


def get_optional_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    session: Session = Depends(get_db),
) -> User | None:
    if credentials is None:
        return None
    return get_current_user(credentials=credentials, session=session)


def require_role(*allowed_roles: UserRole) -> Callable[..., User]:
    def role_dependency(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tiene permisos para esta acción.",
            )
        return current_user

    return role_dependency


def ensure_owner_or_admin(owner_user_id: int, current_user: User) -> None:
    """Reusable guard for future seller-owned resources."""
    if current_user.role == UserRole.ADMIN:
        return
    if current_user.role != UserRole.VENDEDOR or current_user.user_id != owner_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tiene permisos para este recurso.",
        )
