from collections.abc import Iterator

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
from app.models.category import Category
from app.models.product import Product
from app.models.status import Status, StatusApplicability
from app.models.status_history import StatusHistory
from app.models.user import User
from app.routers.auctions import router
from app.routers.me import router as me_router


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

    statuses = [(1, "ACTIVO"), (2, "DESACTIVADO"), (3, "PROGRAMADA"), (4, "ACTIVA"), (5, "CERRADA"), (6, "FINALIZADA_SIN_GANADOR"), (7, "CANCELADA")]
    with factory() as db:
        for status_id, code in statuses:
            db.add(Status(status_id=status_id, code=code, name=code))
        db.flush()
        for status_id, entity in [(1, "USER"), (1, "PRODUCT"), (3, "AUCTION"), (4, "AUCTION"), (5, "AUCTION"), (6, "AUCTION"), (7, "AUCTION")]:
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
    app.include_router(me_router, prefix="/api/v1")

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
