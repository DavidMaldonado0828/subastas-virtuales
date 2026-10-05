from collections.abc import Iterator
from datetime import datetime

import jwt
import pytest
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import ensure_owner_or_admin, get_current_user, require_role
from app.core.config import settings
from app.core.enums import UserRole
from app.core.security import hash_password, verify_password
from app.db.base import Base
from app.db.session import get_db
from app.models.status import Status, StatusApplicability
from app.models.user import User
from app.routers.auth import router as auth_router


@pytest.fixture
def auth_api(monkeypatch: pytest.MonkeyPatch) -> Iterator[tuple[TestClient, sessionmaker[Session]]]:
    monkeypatch.setattr(settings, "jwt_secret_key", "pytest-only-signing-secret-long-enough")
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    test_session = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    with test_session() as session:
        for status_id, code, name in (
            (1, "ACTIVO", "Activo"),
            (2, "BLOQUEADO", "Bloqueado"),
            (3, "DESACTIVADO", "Desactivado"),
        ):
            session.add(Status(status_id=status_id, code=code, name=name))
            session.add(StatusApplicability(status_id=status_id, entity_type="USER"))
        session.commit()

    test_app = FastAPI()
    test_app.include_router(auth_router, prefix="/api/v1")

    def override_db() -> Iterator[Session]:
        with test_session() as session:
            yield session

    test_app.dependency_overrides[get_db] = override_db

    @test_app.get("/test/seller-only")
    def seller_only(user: User = Depends(require_role(UserRole.VENDEDOR))) -> dict[str, int]:
        return {"user_id": user.user_id}

    @test_app.get("/test/owned-resource/{owner_id}")
    def owned_resource(owner_id: int, user: User = Depends(get_current_user)) -> dict[str, int]:
        ensure_owner_or_admin(owner_id, user)
        return {"owner_id": owner_id}

    with TestClient(test_app) as client:
        yield client, test_session

    test_app.dependency_overrides.clear()
    engine.dispose()


def register_payload(**overrides: object) -> dict[str, object]:
    payload: dict[str, object] = {
        "role": "VENDEDOR",
        "name": "Vendedora de prueba",
        "alias": "seller-test",
        "email": "seller@example.com",
        "password": "test-pass-123",
        "phone_number": "+573001112233",
    }
    payload.update(overrides)
    return payload


def create_registered_user(
    client: TestClient,
    *,
    role: str = "VENDEDOR",
    alias: str = "seller-test",
    email: str = "seller@example.com",
) -> dict[str, object]:
    response = client.post(
        "/api/v1/auth/register",
        json=register_payload(
            role=role,
            alias=alias,
            email=email,
            accept_bid_policy=(role == "POSTOR"),
        ),
    )
    assert response.status_code == 201, response.text
    return response.json()


def login(client: TestClient, email: str, password: str = "test-pass-123") -> dict[str, object]:
    response = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert response.status_code == 200, response.text
    return response.json()


def test_registers_vendor_and_postor_without_exposing_hash(auth_api: tuple[TestClient, sessionmaker[Session]]) -> None:
    client, test_session = auth_api
    vendor = create_registered_user(client)
    postor = create_registered_user(
        client,
        role="POSTOR",
        alias="bidder-test",
        email="bidder@example.com",
    )

    assert vendor["role"] == "VENDEDOR"
    assert postor["role"] == "POSTOR"
    assert "password_hash" not in vendor
    with test_session() as session:
        stored_vendor = session.scalar(select(User).where(User.email == "seller@example.com"))
        stored_postor = session.scalar(select(User).where(User.email == "bidder@example.com"))
        assert stored_vendor is not None and verify_password("test-pass-123", stored_vendor.password_hash)
        assert stored_vendor.password_hash != "test-pass-123"
        assert stored_postor is not None and stored_postor.bid_policy_accepted_at is not None


def test_registration_rejects_admin_role(auth_api: tuple[TestClient, sessionmaker[Session]]) -> None:
    client, _ = auth_api
    response = client.post("/api/v1/auth/register", json=register_payload(role="ADMIN"))
    assert response.status_code == 422


def test_registration_rejects_postor_without_policy(auth_api: tuple[TestClient, sessionmaker[Session]]) -> None:
    client, _ = auth_api
    response = client.post(
        "/api/v1/auth/register",
        json=register_payload(role="POSTOR", accept_bid_policy=False),
    )
    assert response.status_code == 422
    assert response.json()["detail"] == "El Postor debe aceptar la política de pujas."


@pytest.mark.parametrize("field,value", [("alias", "seller-test"), ("email", "seller@example.com")])
def test_registration_rejects_duplicate_alias_or_email(
    auth_api: tuple[TestClient, sessionmaker[Session]], field: str, value: str
) -> None:
    client, _ = auth_api
    create_registered_user(client)
    duplicate = (
        register_payload(alias=value, email="another@example.com")
        if field == "alias"
        else register_payload(alias="another-alias", email=value)
    )
    response = client.post("/api/v1/auth/register", json=duplicate)
    assert response.status_code == 409


def test_registration_validates_email_and_password_length(auth_api: tuple[TestClient, sessionmaker[Session]]) -> None:
    client, _ = auth_api
    invalid_email = client.post(
        "/api/v1/auth/register",
        json=register_payload(email="not-an-email"),
    )
    short_password = client.post(
        "/api/v1/auth/register",
        json=register_payload(alias="short-pass", email="short@example.com", password="short"),
    )
    long_password = client.post(
        "/api/v1/auth/register",
        json=register_payload(alias="long-pass", email="long@example.com", password="x" * 129),
    )
    assert invalid_email.status_code == 422
    assert short_password.status_code == 422
    assert long_password.status_code == 422


def test_login_returns_expiring_jwt_and_rejects_wrong_password(
    auth_api: tuple[TestClient, sessionmaker[Session]],
) -> None:
    client, _ = auth_api
    create_registered_user(client)

    result = login(client, "seller@example.com")
    assert result["token_type"] == "bearer"
    assert result["user"]["role"] == "VENDEDOR"  # type: ignore[index]
    assert "password_hash" not in result["user"]  # type: ignore[operator]
    claims = jwt.decode(
        str(result["access_token"]),
        settings.jwt_secret_key,
        algorithms=[settings.jwt_algorithm],
    )
    expires_at = datetime.fromisoformat(str(result["expires_at"]))
    assert abs(expires_at.timestamp() - claims["exp"]) < 1
    assert expires_at.timestamp() > datetime.now().timestamp() + (settings.access_token_expire_minutes - 1) * 60

    wrong_password = client.post(
        "/api/v1/auth/login",
        json={"email": "seller@example.com", "password": "incorrect-pass"},
    )
    assert wrong_password.status_code == 401
    assert wrong_password.json()["detail"] == "Email o contrase\u00f1a incorrectos."
    wrong_email = client.post(
        "/api/v1/auth/login",
        json={"email": "missing@example.com", "password": "incorrect-pass"},
    )
    assert wrong_email.status_code == 401
    assert wrong_email.json()["detail"] == wrong_password.json()["detail"]


def test_seeded_admin_can_login_but_admin_cannot_register(
    auth_api: tuple[TestClient, sessionmaker[Session]],
) -> None:
    client, test_session = auth_api
    with test_session() as session:
        session.add(
            User(
                status_id=1,
                role=UserRole.ADMIN,
                name="Admin de prueba",
                alias="admin-test",
                email="admin@example.com",
                password_hash=hash_password("admin-test-password"),
                phone_number="+573001112234",
            )
        )
        session.commit()

    admin = login(client, "admin@example.com", "admin-test-password")
    assert admin["user"]["role"] == "ADMIN"  # type: ignore[index]


@pytest.mark.parametrize("status_id", [2, 3])
def test_login_rejects_blocked_and_deactivated_users(
    auth_api: tuple[TestClient, sessionmaker[Session]], status_id: int
) -> None:
    client, test_session = auth_api
    create_registered_user(client)
    with test_session() as session:
        user = session.scalar(select(User).where(User.email == "seller@example.com"))
        assert user is not None
        user.status_id = status_id
        session.commit()

    response = client.post(
        "/api/v1/auth/login",
        json={"email": "seller@example.com", "password": "test-pass-123"},
    )
    wrong_password = client.post(
        "/api/v1/auth/login",
        json={"email": "seller@example.com", "password": "wrong-password"},
    )
    assert wrong_password.status_code == 401
    assert wrong_password.json()["detail"] == "Email o contrase\u00f1a incorrectos."
    assert response.status_code == 403
    expected_message = (
        "Su cuenta est\u00e1 bloqueada. Contacte al administrador."
        if status_id == 2
        else "Su cuenta est\u00e1 desactivada."
    )
    assert response.json()["detail"] == expected_message


@pytest.mark.parametrize(
    ("status_id", "expected_message"),
    [
        (2, "Su cuenta est\u00e1 bloqueada. Contacte al administrador."),
        (3, "Su cuenta est\u00e1 desactivada."),
    ],
)
def test_previously_issued_token_is_forbidden_after_account_status_change(
    auth_api: tuple[TestClient, sessionmaker[Session]], status_id: int, expected_message: str
) -> None:
    client, test_session = auth_api
    created = create_registered_user(client)
    access_token = login(client, "seller@example.com")["access_token"]
    with test_session() as session:
        user = session.get(User, created["user_id"])
        assert user is not None
        user.status_id = status_id
        session.commit()

    response = client.get("/test/seller-only", headers={"Authorization": f"Bearer {access_token}"})
    assert response.status_code == 403
    assert response.json()["detail"] == expected_message


def test_protected_route_rejects_missing_token_and_wrong_role(
    auth_api: tuple[TestClient, sessionmaker[Session]],
) -> None:
    client, _ = auth_api
    unauthenticated = client.get("/test/seller-only")
    assert unauthenticated.status_code == 401
    invalid_token = client.get("/test/seller-only", headers={"Authorization": "Bearer invalid-token"})
    assert invalid_token.status_code == 401
    expired_token = jwt.encode(
        {"sub": "1", "exp": 0}, settings.jwt_secret_key, algorithm=settings.jwt_algorithm
    )
    expired = client.get("/test/seller-only", headers={"Authorization": f"Bearer {expired_token}"})
    assert expired.status_code == 401

    create_registered_user(client, role="POSTOR", alias="bidder-test", email="bidder@example.com")
    token_result = login(client, "bidder@example.com")
    forbidden = client.get(
        "/test/seller-only",
        headers={"Authorization": f"Bearer {token_result['access_token']}"},
    )
    assert forbidden.status_code == 403


def test_owner_guard_allows_owner_and_rejects_other_seller(
    auth_api: tuple[TestClient, sessionmaker[Session]],
) -> None:
    client, _ = auth_api
    vendor = create_registered_user(client)
    token_result = login(client, "seller@example.com")
    token = str(token_result["access_token"])

    own_resource = client.get(
        f"/test/owned-resource/{vendor['user_id']}",
        headers={"Authorization": f"Bearer {token}"},
    )
    other_resource = client.get(
        f"/test/owned-resource/{vendor['user_id'] + 100}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert own_resource.status_code == 200
    assert other_resource.status_code == 403
