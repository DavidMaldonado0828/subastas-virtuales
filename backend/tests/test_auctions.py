from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import jwt
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import settings
from app.core.enums import UserRole
from app.db.base import Base
from app.db.session import get_db
from app.models.auction import Auction
from app.models.bid import Bid
from app.models.category import Category
from app.models.product import Product
from app.models.status import Status, StatusApplicability
from app.models.status_history import StatusHistory
from app.models.user import User
from app.routers.auctions import router


@pytest.fixture
def auction_api(monkeypatch: pytest.MonkeyPatch) -> Iterator[tuple[TestClient, sessionmaker[Session]]]:
    monkeypatch.setattr(settings, "jwt_secret_key", "test-auction-secret-at-least-32-chars")
    engine = create_engine("sqlite+pysqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)

    @event.listens_for(factory.class_, "before_flush")
    def assign_sqlite_history_ids(session, flush_context, instances):
        for row in session.new:
            if isinstance(row, StatusHistory) and row.history_id is None:
                row.history_id = 1 + session.query(StatusHistory).count()

    statuses = [(1, "ACTIVO"), (2, "DESACTIVADO"), (3, "PROGRAMADA"), (4, "ACTIVA"), (5, "CERRADA")]
    with factory() as db:
        for status_id, code in statuses:
            db.add(Status(status_id=status_id, code=code, name=code))
        db.flush()
        for status_id, entity in [(1, "USER"), (1, "PRODUCT"), (3, "AUCTION"), (4, "AUCTION"), (5, "AUCTION")]:
            db.add(StatusApplicability(status_id=status_id, entity_type=entity))
        db.add_all([
            User(user_id=1, status_id=1, role=UserRole.VENDEDOR, name="Vendedor", alias="seller", email="seller@example.com", password_hash="x", phone_number="123"),
            User(user_id=2, status_id=1, role=UserRole.VENDEDOR, name="Otro", alias="other", email="other@example.com", password_hash="x", phone_number="123"),
            User(user_id=3, status_id=1, role=UserRole.POSTOR, name="Postor", alias="bidder", email="bidder@example.com", password_hash="x", phone_number="123"),
            Category(category_id=1, status_id=1, name="Arte", description="Arte"),
            Product(product_id=1, seller_id=1, category_id=1, status_id=1, name="Cuadro", description="Óleo"),
            Product(product_id=2, seller_id=2, category_id=1, status_id=1, name="Otro", description="Producto de otro"),
            Product(product_id=3, seller_id=1, category_id=1, status_id=2, name="Inactivo", description="Producto inactivo"),
        ])
        db.commit()

    app = FastAPI()
    app.include_router(router, prefix="/api/v1")

    def override_db() -> Iterator[Session]:
        with factory() as db:
            yield db

    app.dependency_overrides[get_db] = override_db
    token = jwt.encode({"sub": "1", "role": "VENDEDOR", "exp": 4102444800}, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    with TestClient(app) as client:
        client.headers["Authorization"] = f"Bearer {token}"
        yield client, factory
    app.dependency_overrides.clear()
    engine.dispose()


def dates() -> tuple[str, str]:
    start = datetime.now(UTC) + timedelta(days=2)
    end = start + timedelta(days=2)
    return start.isoformat(), end.isoformat()


def create_payload(product_id: int = 1, **overrides: object) -> dict[str, object]:
    start, end = dates()
    return {"product_id": product_id, "base_price": "100.25", "minimum_increment": "5.10", "start_date": start, "end_date": end, **overrides}


def test_create_scheduled_auction_and_record_history(auction_api):
    client, factory = auction_api
    response = client.post("/api/v1/auctions", json=create_payload())
    assert response.status_code == 201, response.text
    data = response.json()
    assert Decimal(data["base_price"]) == Decimal("100.25")
    assert data["base_price"] == "100.25"
    assert data["minimum_increment"] == "5.10"
    with factory() as db:
        auction = db.get(Auction, data["auction_id"])
        assert auction is not None and auction.status_id == 3
        event_row = db.scalar(select(StatusHistory).where(StatusHistory.entity_type == "AUCTION", StatusHistory.entity_id == auction.auction_id))
        assert event_row is not None
        assert event_row.new_status_code == "PROGRAMADA"
        assert event_row.event_source == "API_CREATE_AUCTION"
        assert event_row.changed_by == 1


def test_create_rejects_invalid_product_amount_dates_and_duplicate_auction(auction_api):
    client, _ = auction_api
    assert client.post("/api/v1/auctions", json=create_payload(product_id=2)).status_code == 404
    assert client.post("/api/v1/auctions", json=create_payload(product_id=3)).status_code == 409
    assert "ACTIVO" in client.post("/api/v1/auctions", json=create_payload(product_id=3)).json()["detail"]
    assert client.post("/api/v1/auctions", json=create_payload(base_price="0")).status_code == 422
    assert client.post("/api/v1/auctions", json=create_payload(minimum_increment="-1")).status_code == 422
    start, end = dates()
    assert client.post("/api/v1/auctions", json=create_payload(start_date=start.replace("+00:00", ""))).status_code == 422
    assert client.post("/api/v1/auctions", json=create_payload(end_date=start)).status_code == 422
    assert client.post("/api/v1/auctions", json=create_payload()).status_code == 201
    assert client.post("/api/v1/auctions", json=create_payload()).status_code == 409


def test_update_without_bids_and_reject_with_bid(auction_api):
    client, factory = auction_api
    created = client.post("/api/v1/auctions", json=create_payload()).json()
    start, end = dates()
    updated = client.patch(f"/api/v1/auctions/{created['auction_id']}", json={"base_price": "200.55", "minimum_increment": "7.25", "start_date": start, "end_date": end})
    assert updated.status_code == 200, updated.text
    assert Decimal(updated.json()["base_price"]) == Decimal("200.55")
    with factory() as db:
        db.add(Bid(auction_id=created["auction_id"], participant_id=3, amount=Decimal("200.55")))
        db.commit()
    rejected = client.patch(f"/api/v1/auctions/{created['auction_id']}", json={"base_price": "250"})
    assert rejected.status_code == 409
    assert "pujas" in rejected.json()["detail"]


def test_update_owner_and_validation(auction_api):
    client, _ = auction_api
    created = client.post("/api/v1/auctions", json=create_payload()).json()
    other_token = jwt.encode({"sub": "2", "role": "VENDEDOR", "exp": 4102444800}, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    client.headers["Authorization"] = f"Bearer {other_token}"
    assert client.patch(f"/api/v1/auctions/{created['auction_id']}", json={"base_price": "205"}).status_code == 404
    owner_token = jwt.encode({"sub": "1", "role": "VENDEDOR", "exp": 4102444800}, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    client.headers["Authorization"] = f"Bearer {owner_token}"
    assert client.patch(f"/api/v1/auctions/{created['auction_id'] + 50}", json={"base_price": "200"}).status_code == 404
    assert client.patch(f"/api/v1/auctions/{created['auction_id']}", json={"minimum_increment": "0"}).status_code == 422
    start, end = dates()
    assert client.patch(f"/api/v1/auctions/{created['auction_id']}", json={"start_date": start.replace("+00:00", ""), "end_date": end}).status_code == 422
