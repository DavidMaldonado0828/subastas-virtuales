from datetime import UTC, datetime, timedelta
from decimal import Decimal

import jwt
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.core.config import settings
from app.models.auction import Auction
from app.models.bid import Bid
from app.models.status_history import StatusHistory
from app.jobs.auction_statuses import update_auction_statuses


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


def test_seller_auction_list_is_owned_paged_and_includes_status_product_and_bid_count(auction_api):
    client, factory = auction_api
    start = datetime.now(UTC) + timedelta(days=1)
    end = start + timedelta(days=1)
    with factory() as db:
        db.add_all([
            Auction(product_id=1, status_id=3, base_price=Decimal("100.00"), minimum_increment=Decimal("5.00"), start_date=start, end_date=end),
            Auction(product_id=3, status_id=4, base_price=Decimal("200.00"), minimum_increment=Decimal("10.00"), start_date=start, end_date=end),
            Auction(product_id=2, status_id=3, base_price=Decimal("300.00"), minimum_increment=Decimal("15.00"), start_date=start, end_date=end),
        ])
        db.flush()
        seller_auction_ids = [row.auction_id for row in db.query(Auction).order_by(Auction.auction_id).all()[:2]]
        db.add(Bid(auction_id=seller_auction_ids[0], participant_id=3, amount=Decimal("110.00")))
        db.commit()

    first = client.get("/api/v1/me/seller/auctions?limit=1&offset=0")
    assert first.status_code == 200
    first_page = first.json()
    assert first_page["total"] == 2 and len(first_page["items"]) == 1
    assert first_page["items"][0]["status"] == "PROGRAMADA"
    assert first_page["items"][0]["product"]["name"] == "Cuadro"
    assert first_page["items"][0]["bid_count"] == 1
    second_page = client.get("/api/v1/me/seller/auctions?limit=1&offset=1").json()
    assert len(second_page["items"]) == 1

    bidder_token = jwt.encode({"sub": "3", "role": "POSTOR", "exp": 4102444800},
                              settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    client.headers["Authorization"] = f"Bearer {bidder_token}"
    assert client.get("/api/v1/me/seller/auctions").status_code == 403
    client.headers.pop("Authorization")
    assert client.get("/api/v1/me/seller/auctions").status_code == 401


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


def test_public_catalog_without_token_and_excludes_cancelled(auction_api):
    client, factory = auction_api
    created = client.post("/api/v1/auctions", json=create_payload()).json()
    with factory() as db:
        db.add(Auction(product_id=1, status_id=7, base_price=Decimal("40.00"), minimum_increment=Decimal("2.00"), start_date=datetime.now(UTC), end_date=datetime.now(UTC) + timedelta(days=1)))
        db.commit()
    client.headers.pop("Authorization")
    response = client.get("/api/v1/auctions")
    assert response.status_code == 200
    data = response.json()
    assert data["limit"] == 20 and data["offset"] == 0
    assert [item["id"] for item in data["items"]] == [created["auction_id"]]
    assert data["items"][0]["product"]["category"] == "Arte"
    assert data["items"][0]["seller_alias"] == "seller"
    assert client.get("/api/v1/auctions?limit=101").status_code == 422


def test_public_detail_has_leader_alias_without_personal_data(auction_api):
    client, factory = auction_api
    created = client.post("/api/v1/auctions", json=create_payload()).json()
    with factory() as db:
        db.add(Bid(auction_id=created["auction_id"], participant_id=3, amount=Decimal("120.50")))
        db.commit()
    client.headers.pop("Authorization")
    response = client.get(f"/api/v1/auctions/{created['auction_id']}")
    assert response.status_code == 200, response.text
    detail = response.json()
    assert detail["leader_bid"] == {"amount": "120.50", "bidder_alias": "bidder"}
    assert detail["remaining_seconds"] > 0
    assert not {"email", "phone_number", "address", "password_hash"}.intersection(detail)
    assert not {"email", "phone_number", "address", "password_hash"}.intersection(detail["leader_bid"])


def test_temporal_state_and_scheduler_transitions_are_idempotent(auction_api):
    client, factory = auction_api
    now = datetime.now(UTC)
    with factory() as db:
        auction = Auction(product_id=1, status_id=3, base_price=Decimal("100.00"), minimum_increment=Decimal("5.00"), start_date=now - timedelta(minutes=2), end_date=now + timedelta(minutes=2))
        db.add(auction)
        db.commit()
        auction_id = auction.auction_id
    client.headers.pop("Authorization")
    detail = client.get(f"/api/v1/auctions/{auction_id}").json()
    assert detail["status"] == "ACTIVA"
    assert update_auction_statuses(factory, now=now) == 1
    assert update_auction_statuses(factory, now=now) == 0
    with factory() as db:
        auction = db.get(Auction, auction_id)
        auction.end_date = now - timedelta(seconds=1)
        db.commit()
    assert client.get(f"/api/v1/auctions/{auction_id}").json()["status"] == "FINALIZADA_SIN_GANADOR"
    assert update_auction_statuses(factory, now=now) == 1
    assert update_auction_statuses(factory, now=now) == 0
    with factory() as db:
        history = db.query(StatusHistory).filter(StatusHistory.entity_id == auction_id, StatusHistory.entity_type == "AUCTION").all()
        events = [row for row in history if row.event_source == "SCHEDULER"]
        assert [(row.old_status_code, row.new_status_code, row.changed_by) for row in events] == [
            ("PROGRAMADA", "ACTIVA", None), ("ACTIVA", "FINALIZADA_SIN_GANADOR", None)
        ]
