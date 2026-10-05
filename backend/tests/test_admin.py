from collections.abc import Iterator
from datetime import UTC, datetime, timedelta

import jwt
import pytest
from fastapi import FastAPI
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import settings
from app.core.enums import UserRole
from app.db.base import Base
from app.db.session import get_db
from app.jobs.auction_statuses import update_auction_statuses
from app.models.auction import Auction
from app.models.auction_cancellation import AuctionCancellation
from app.models.bid import Bid
from app.models.category import Category
from app.models.product import Product
from app.models.status import Status, StatusApplicability
from app.models.status_history import StatusHistory
from app.models.user import User
from app.routers.admin import router
from app.services.auth import login
from app.core.security import hash_password
from app.schemas.auth import LoginRequest


@pytest.fixture
def admin_api(monkeypatch: pytest.MonkeyPatch) -> Iterator[tuple[TestClient, sessionmaker[Session]]]:
    monkeypatch.setattr(settings, "jwt_secret_key", "test-admin-secret-at-least-32-characters")
    engine = create_engine("sqlite+pysqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)

    @event.listens_for(factory.class_, "before_flush")
    def assign_history_ids(session, flush_context, instances):
        for row in session.new:
            if isinstance(row, StatusHistory) and row.history_id is None:
                row.history_id = 1 + session.query(StatusHistory).count()

    with factory() as db:
        status_codes = ["ACTIVO", "BLOQUEADO", "PROGRAMADA", "ACTIVA", "CERRADA", "FINALIZADA_SIN_GANADOR", "CANCELADA"]
        for index, code in enumerate(status_codes, 1):
            db.add(Status(status_id=index, code=code, name=code))
        db.flush()
        for code, entity in [("ACTIVO", "USER"), ("BLOQUEADO", "USER"),
                             *((c, "AUCTION") for c in status_codes[2:])]:
            status_id = status_codes.index(code) + 1
            db.add(StatusApplicability(status_id=status_id, entity_type=entity))
        db.add_all([
            User(user_id=1, status_id=1, role=UserRole.ADMIN, name="Admin", alias="admin", email="admin@example.com", password_hash=hash_password("admin-test-password"), phone_number="1"),
            User(user_id=2, status_id=1, role=UserRole.VENDEDOR, name="Seller", alias="seller", email="seller@example.com", password_hash=hash_password("seller-test-password"), phone_number="2"),
            User(user_id=3, status_id=1, role=UserRole.POSTOR, name="Bidder", alias="bidder", email="bidder@example.com", password_hash=hash_password("bidder-test-password"), phone_number="3"),
            Category(category_id=1, status_id=1, name="Arte", description="Arte"),
            Product(product_id=1, seller_id=2, category_id=1, status_id=1, name="Cuadro", brand="Taller", description="Óleo"),
            Auction(auction_id=1, product_id=1, status_id=3, base_price=100, minimum_increment=10,
                    start_date=datetime.now(UTC) + timedelta(days=1), end_date=datetime.now(UTC) + timedelta(days=2)),
            Auction(auction_id=2, product_id=1, status_id=4, base_price=100, minimum_increment=10,
                    start_date=datetime.now(UTC) - timedelta(days=1), end_date=datetime.now(UTC) + timedelta(days=1)),
            Auction(auction_id=3, product_id=1, status_id=5, base_price=100, minimum_increment=10,
                    start_date=datetime.now(UTC) - timedelta(days=2), end_date=datetime.now(UTC) - timedelta(days=1)),
        ])
        db.add(Bid(auction_id=2, participant_id=3, amount=120))
        db.commit()

    app = FastAPI()
    app.include_router(router, prefix="/api/v1")

    def override_db() -> Iterator[Session]:
        with factory() as db:
            yield db

    app.dependency_overrides[get_db] = override_db
    with TestClient(app) as client:
        yield client, factory
    app.dependency_overrides.clear()
    engine.dispose()


def _token(role: str, user_id: int) -> str:
    return jwt.encode({"sub": str(user_id), "role": role, "exp": 4102444800},
                      settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def test_user_status_admin_only_and_guards(admin_api):
    client, factory = admin_api
    path = "/api/v1/admin/users/2/status"
    assert client.patch(path, json={"status": "BLOQUEADO"}).status_code == 401
    for role, user_id in (("VENDEDOR", 2), ("POSTOR", 3)):
        response = client.patch(path, json={"status": "BLOQUEADO"}, headers={"Authorization": f"Bearer {_token(role, user_id)}"})
        assert response.status_code == 403
    admin_headers = {"Authorization": f"Bearer {_token('ADMIN', 1)}"}
    response = client.patch(path, json={"status": "BLOQUEADO"}, headers=admin_headers)
    assert response.status_code == 200
    old_token_headers = {"Authorization": f"Bearer {_token('VENDEDOR', 2)}"}
    blocked_response = client.get("/api/v1/admin/auctions", headers=old_token_headers)
    assert blocked_response.status_code == 403
    assert blocked_response.json()["detail"] == "Su cuenta est\u00e1 bloqueada. Contacte al administrador."
    with factory() as db:
        with pytest.raises(HTTPException) as error:
            login(db, LoginRequest(email="seller@example.com", password="seller-test-password"))
        assert error.value.status_code == 403
    reactivated = client.patch(path, json={"status": "ACTIVO"}, headers=admin_headers)
    assert reactivated.status_code == 200
    with factory() as db:
        token, _, user = login(db, LoginRequest(email="seller@example.com", password="seller-test-password"))
        assert token and user.user_id == 2


def test_user_status_rejects_admin_self_and_records_history(admin_api):
    client, factory = admin_api
    headers = {"Authorization": f"Bearer {_token('ADMIN', 1)}"}
    assert client.patch("/api/v1/admin/users/1/status", json={"status": "BLOQUEADO"}, headers=headers).status_code == 409
    assert client.patch("/api/v1/admin/users/1/status", json={"status": "ACTIVO"}, headers=headers).status_code == 409
    assert client.patch("/api/v1/admin/users/2/status", json={"status": "BLOQUEADO"}, headers=headers).status_code == 200
    with factory() as db:
        events = db.query(StatusHistory).filter_by(entity_type="USER", entity_id=2).all()
        assert len(events) == 1
        assert (events[0].old_status_code, events[0].new_status_code, events[0].event_source) == ("ACTIVO", "BLOQUEADO", "ADMIN")


def test_admin_auction_listing_is_paged_filtered_and_private(admin_api):
    client, _ = admin_api
    headers = {"Authorization": f"Bearer {_token('ADMIN', 1)}"}
    assert client.get("/api/v1/admin/auctions").status_code == 401
    for role, user_id in (("VENDEDOR", 2), ("POSTOR", 3)):
        assert client.get("/api/v1/admin/auctions", headers={"Authorization": f"Bearer {_token(role, user_id)}"}).status_code == 403
    response = client.get("/api/v1/admin/auctions?limit=2&offset=0", headers=headers)
    assert response.status_code == 200
    page = response.json()
    assert page["total"] == 3 and len(page["items"]) == 2
    assert page["items"][1]["leader_bid"] == {"amount": "120.00", "bidder_alias": "bidder"}
    assert page["items"][1]["seller_alias"] == "seller"
    assert "email" not in str(page) and "phone_number" not in str(page)
    filtered = client.get("/api/v1/admin/auctions?status=CERRADA", headers=headers).json()
    assert filtered["total"] == 1 and filtered["items"][0]["status"] == "CERRADA"


def test_admin_user_listing_search_status_pagination_and_privacy(admin_api):
    client, _ = admin_api
    headers = {"Authorization": f"Bearer {_token('ADMIN', 1)}"}
    assert client.get("/api/v1/admin/users").status_code == 401
    for role, user_id in (("VENDEDOR", 2), ("POSTOR", 3)):
        response = client.get("/api/v1/admin/users", headers={"Authorization": f"Bearer {_token(role, user_id)}"})
        assert response.status_code == 403

    page = client.get("/api/v1/admin/users?limit=2&offset=0", headers=headers).json()
    assert page["total"] == 3 and len(page["items"]) == 2
    matched = client.get("/api/v1/admin/users?search=bidder@example.com", headers=headers)
    assert matched.status_code == 200
    result = matched.json()
    assert result["total"] == 1
    assert result["items"] == [{"id": 3, "alias": "bidder", "role": "POSTOR", "status": "ACTIVO"}]
    assert "email" not in str(result) and "password" not in str(result) and "phone_number" not in str(result)
    assert client.get("/api/v1/admin/users?search=bidder", headers=headers).json()["total"] == 1

    assert client.patch("/api/v1/admin/users/2/status", json={"status": "BLOQUEADO"}, headers=headers).status_code == 200
    blocked = client.get("/api/v1/admin/users?status=BLOQUEADO", headers=headers).json()
    assert blocked["total"] == 1 and blocked["items"][0]["alias"] == "seller"
    assert client.get("/api/v1/admin/users?status=UNKNOWN", headers=headers).status_code == 422


@pytest.mark.parametrize("status_id", [3, 4])
def test_admin_cancel_auction_preserves_bids_and_records_atomically(admin_api, status_id):
    client, factory = admin_api
    if status_id != 4:
        with factory() as db:
            auction = db.get(Auction, 1)
            auction.status_id = status_id
            db.commit()
        auction_id = 1
    else:
        auction_id = 2
    headers = {"Authorization": f"Bearer {_token('ADMIN', 1)}"}
    url = f"/api/v1/admin/auctions/{auction_id}/cancel"
    assert client.post(url, json={"reason": "conflicto usuario"}).status_code == 401
    for role, user_id in (("VENDEDOR", 2), ("POSTOR", 3)):
        assert client.post(url, json={"reason": "conflicto usuario"}, headers={"Authorization": f"Bearer {_token(role, user_id)}"}).status_code == 403
    response = client.post(url, json={"reason": "cancelación por disputa"}, headers=headers)
    assert response.status_code == 200
    with factory() as db:
        auction = db.get(Auction, auction_id)
        assert auction and db.query(Bid).filter_by(auction_id=auction_id).count() == (1 if auction_id == 2 else 0)
        cancellation = db.get(AuctionCancellation, auction_id)
        event = db.query(StatusHistory).filter_by(entity_type="AUCTION", entity_id=auction_id).one()
        assert cancellation and cancellation.admin_user_id == 1 and cancellation.reason_detail["reason"] == "cancelación por disputa"
        assert event.new_status_code == "CANCELADA" and event.event_source == "ADMIN"


def test_cancel_requires_reason_and_rejects_closed_or_missing_auction(admin_api):
    client, _ = admin_api
    headers = {"Authorization": f"Bearer {_token('ADMIN', 1)}"}
    assert client.post("/api/v1/admin/auctions/1/cancel", json={"reason": "corto"}, headers=headers).status_code == 422
    assert client.post("/api/v1/admin/auctions/3/cancel", json={"reason": "motivo suficientemente largo"}, headers=headers).status_code == 409
    assert client.post("/api/v1/admin/auctions/99/cancel", json={"reason": "motivo suficientemente largo"}, headers=headers).status_code == 404
    assert client.post("/api/v1/admin/auctions/1/cancel", json={"reason": "          "}, headers=headers).status_code == 422


def test_scheduler_does_not_change_cancelled_auction(admin_api):
    _, factory = admin_api
    with factory() as db:
        auction = db.get(Auction, 1)
        auction.status_id = 7
        auction.start_date = datetime.now(UTC) - timedelta(days=2)
        auction.end_date = datetime.now(UTC) - timedelta(days=1)
        db.commit()
    assert update_auction_statuses(factory, now=datetime.now(UTC)) == 0
    with factory() as db:
        auction = db.get(Auction, 1)
        assert auction and auction.status_id == 7
        assert db.query(StatusHistory).filter_by(entity_type="AUCTION", entity_id=1).count() == 0
