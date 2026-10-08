from collections.abc import Iterator
from datetime import datetime
from decimal import Decimal

import jwt
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import settings
from app.core.enums import UserRole
from app.db.base import Base
from app.db.session import get_db
from app.models.auction import Auction
from app.models.category import Category
from app.models.product import Product
from app.models.status import Status, StatusApplicability
from app.models.status_history import StatusHistory
from app.models.user import User
from app.routers.products import router


@pytest.fixture
def api(monkeypatch: pytest.MonkeyPatch) -> Iterator[tuple[TestClient, sessionmaker[Session]]]:
    monkeypatch.setattr(settings, "jwt_secret_key", "test-products-secret-at-least-32-chars")
    engine = create_engine("sqlite+pysqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    @event.listens_for(factory.class_, "before_flush")
    def assign_sqlite_history_ids(session, flush_context, instances):
        next_id = 1 + session.query(StatusHistory).count()
        for row in session.new:
            if isinstance(row, StatusHistory) and row.history_id is None:
                row.history_id = next_id
                next_id += 1
    status_codes = ["ACTIVO", "DESACTIVADO", "ACTIVA", "CERRADA", "PROGRAMADA", "CANCELADA", "DESACTIVADO_POR_INCUMPLIMIENTO", "FINALIZADA_SIN_GANADOR"]
    with factory() as db:
        for i, code in enumerate(status_codes, 1):
            db.add(Status(status_id=i, code=code, name=code))
        db.flush()
        for status_id, entity in [(1, "USER"), (1, "CATEGORY"), (1, "PRODUCT"), (2, "CATEGORY"), (2, "PRODUCT"), (7, "PRODUCT"), (3, "AUCTION"), (4, "AUCTION"), (5, "AUCTION"), (6, "AUCTION"), (8, "AUCTION")]:
            db.add(StatusApplicability(status_id=status_id, entity_type=entity))
        db.add_all([
            User(user_id=1, status_id=1, role=UserRole.VENDEDOR, name="Vendedor", alias="seller", email="s@example.com", password_hash="x", phone_number="123"),
            User(user_id=2, status_id=1, role=UserRole.VENDEDOR, name="Otro", alias="other", email="o@example.com", password_hash="x", phone_number="123"),
            User(user_id=3, status_id=1, role=UserRole.POSTOR, name="Postor", alias="bidder", email="b@example.com", password_hash="x", phone_number="123"),
            Category(category_id=1, status_id=1, name="Arte", description="Arte"),
            Category(category_id=2, status_id=2, name="Inactiva", description="No disponible"),
        ])
        db.commit()
    app = FastAPI()
    app.include_router(router, prefix="/api/v1")

    def override_db() -> Iterator[Session]:
        with factory() as db:
            yield db

    app.dependency_overrides[get_db] = override_db

    def token(uid: int, role: str) -> str:
        return jwt.encode({"sub": str(uid), "role": role, "exp": 4102444800}, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)

    with TestClient(app) as client:
        client.headers["Authorization"] = f"Bearer {token(1, 'VENDEDOR')}"
        client.other_token = token(2, "VENDEDOR")
        client.bidder_token = token(3, "POSTOR")
        yield client, factory
    app.dependency_overrides.clear()
    engine.dispose()


def payload(**changes: object) -> dict[str, object]:
    result: dict[str, object] = {"name": "Cuadro", "description": "Óleo", "category_id": 1, "brand": "Acme", "image_url": None}
    result.update(changes)
    return result


def test_categories_public_and_product_creation_validation(api):
    client, _ = api
    assert client.get("/api/v1/categories").status_code == 200
    missing_auth = TestClient(client.app)
    assert missing_auth.post("/api/v1/products", json=payload()).status_code == 401
    assert client.post("/api/v1/products", json=payload(category_id=99)).status_code == 422
    assert client.post("/api/v1/products", json=payload(category_id=2)).status_code == 422
    response = client.post("/api/v1/products", json={"name": "Cuadro", "description": "Óleo", "category_id": 1})
    assert response.status_code == 201, response.text
    assert response.json()["brand"] is None and response.json()["image_url"] is None
    assert response.json()["status"] == "ACTIVO" and response.json()["status_id"] == 1


def test_seller_ownership_filters_and_patch(api):
    client, factory = api
    one = client.post("/api/v1/products", json=payload()).json()
    with factory() as db:
        db.add(Product(seller_id=2, category_id=1, status_id=1, name="Otro cuadro", brand="Acme", description="Otro"))
        db.commit()
    assert len(client.get("/api/v1/products?brand=acme&category_id=1&name=cuad").json()) == 1
    assert client.get(f"/api/v1/products/{one['product_id']}").status_code == 200
    client.headers["Authorization"] = f"Bearer {client.other_token}"
    assert client.get(f"/api/v1/products/{one['product_id']}").status_code == 404
    client.headers["Authorization"] = "Bearer " + jwt.encode({"sub": "3", "role": "POSTOR", "exp": 4102444800}, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    assert client.get("/api/v1/products").status_code == 403
    client.headers["Authorization"] = f"Bearer {jwt.encode({'sub': '1', 'role': 'VENDEDOR', 'exp': 4102444800}, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)}"
    changed = client.patch(f"/api/v1/products/{one['product_id']}", json={"name": "Nuevo", "category_id": 1})
    assert changed.status_code == 200 and changed.json()["name"] == "Nuevo"
    assert changed.json()["status"] == "ACTIVO"


def test_patch_after_active_or_closed_and_delete_rules(api):
    client, factory = api
    product = client.post("/api/v1/products", json=payload()).json()
    with factory() as db:
        auction = Auction(product_id=product["product_id"], status_id=3, base_price=1, minimum_increment=1, start_date=datetime(2025, 1, 1), end_date=datetime(2025, 1, 2))
        db.add(auction)
        db.flush()
        db.add(StatusHistory(entity_type="AUCTION", entity_id=auction.auction_id, old_status_code="PROGRAMADA", new_status_code="ACTIVA", event_source="test"))
        db.commit()
    assert client.patch(f"/api/v1/products/{product['product_id']}", json={"description": "Actualizada", "image_url": "https://example.test/i.jpg"}).status_code == 200
    assert client.patch(f"/api/v1/products/{product['product_id']}", json={"name": "No permitido"}).status_code == 409
    deleted = client.delete(f"/api/v1/products/{product['product_id']}")
    assert deleted.status_code == 409 and "subasta ACTIVA" in deleted.json()["detail"]
    fresh = client.post("/api/v1/products", json=payload(name="Sin subasta")).json()
    assert client.delete(f"/api/v1/products/{fresh['product_id']}").json()["result"] == "DELETED"
    with factory() as db:
        assert db.get(Product, fresh["product_id"]) is None


def test_delete_product_with_scheduled_auction_cancels_both_and_records_history(api):
    client, factory = api
    product = client.post("/api/v1/products", json=payload()).json()
    with factory() as db:
        auction = Auction(product_id=product["product_id"], status_id=5, base_price=Decimal("1.00"), minimum_increment=Decimal("0.50"), start_date=datetime(2027, 1, 1), end_date=datetime(2027, 1, 2))
        db.add(auction)
        db.commit()
        auction_id = auction.auction_id
    response = client.delete(f"/api/v1/products/{product['product_id']}")
    assert response.status_code == 200 and response.json()["result"] == "DEACTIVATED"
    with factory() as db:
        assert db.get(Product, product["product_id"]).status_id == 2
        assert db.get(Auction, auction_id).status_id == 6
        events = db.query(StatusHistory).filter(StatusHistory.event_source == "API_DEACTIVATE_PRODUCT").all()
        assert {(e.entity_type, e.entity_id, e.old_status_code, e.new_status_code) for e in events} == {
            ("PRODUCT", product["product_id"], "ACTIVO", "DESACTIVADO"),
            ("AUCTION", auction_id, "PROGRAMADA", "CANCELADA"),
        }


@pytest.mark.parametrize(("status_id", "status_code"), [
    (4, "CERRADA"), (8, "FINALIZADA_SIN_GANADOR"), (6, "CANCELADA"),
])
def test_delete_with_final_or_cancelled_auction_deactivates_product_without_changing_auction(api, status_id, status_code):
    client, factory = api
    product = client.post("/api/v1/products", json=payload()).json()
    with factory() as db:
        auction = Auction(product_id=product["product_id"], status_id=status_id,
            base_price=Decimal("10.00"), minimum_increment=Decimal("1.00"),
            start_date=datetime(2025, 1, 1), end_date=datetime(2025, 1, 2))
        db.add(auction)
        db.commit()
        auction_id = auction.auction_id

    response = client.delete(f"/api/v1/products/{product['product_id']}")
    assert response.status_code == 200
    assert response.json()["result"] == "DEACTIVATED"
    assert response.json()["status"] == "DESACTIVADO"
    with factory() as db:
        assert db.get(Product, product["product_id"]).status_id == 2
        assert db.get(Auction, auction_id).status_id == status_id
        events = db.query(StatusHistory).all()
        assert [(event.entity_type, event.entity_id, event.old_status_code, event.new_status_code)
                for event in events] == [("PRODUCT", product["product_id"], "ACTIVO", "DESACTIVADO")]


def test_reactivate_deactivated_product_and_keep_cancelled_auction(api):
    client, factory = api
    product = client.post("/api/v1/products", json=payload()).json()
    with factory() as db:
        db.get(Product, product["product_id"]).status_id = 2
        cancelled_auction = Auction(product_id=product["product_id"], status_id=6,
            base_price=Decimal("10.00"), minimum_increment=Decimal("1.00"),
            start_date=datetime(2027, 1, 1), end_date=datetime(2027, 1, 2))
        db.add(cancelled_auction)
        db.commit()
        auction_id = cancelled_auction.auction_id
    response = client.post(f"/api/v1/products/{product['product_id']}/reactivate")
    assert response.status_code == 200 and response.json()["status_id"] == 1
    assert response.json()["status"] == "ACTIVO"
    with factory() as db:
        assert db.get(Auction, auction_id).status_id == 6
        history = db.query(StatusHistory).filter(StatusHistory.entity_type == "PRODUCT",
            StatusHistory.entity_id == product["product_id"], StatusHistory.event_source == "USER").one()
        assert (history.old_status_code, history.new_status_code, history.changed_by) == ("DESACTIVADO", "ACTIVO", 1)


def test_reactivation_rejects_suspended_active_and_inactive_category_products(api):
    client, factory = api
    active = client.post("/api/v1/products", json=payload()).json()
    suspended = client.post("/api/v1/products", json=payload(name="Suspendido")).json()
    inactive_category = client.post("/api/v1/products", json=payload(name="Categoría inactiva")).json()
    with factory() as db:
        db.get(Product, suspended["product_id"]).status_id = 7
        category_product = db.get(Product, inactive_category["product_id"])
        category_product.status_id = 2
        category_product.category_id = 2
        db.commit()
    suspended_response = client.post(f"/api/v1/products/{suspended['product_id']}/reactivate")
    assert suspended_response.status_code == 409 and "DESACTIVADO" in suspended_response.json()["detail"]
    assert client.post(f"/api/v1/products/{active['product_id']}/reactivate").status_code == 409
    category_response = client.post(f"/api/v1/products/{inactive_category['product_id']}/reactivate")
    assert category_response.status_code == 409 and "categoría" in category_response.json()["detail"]
    client.headers["Authorization"] = f"Bearer {client.other_token}"
    assert client.post(f"/api/v1/products/{suspended['product_id']}/reactivate").status_code == 404
