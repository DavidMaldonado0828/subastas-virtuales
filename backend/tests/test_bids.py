from datetime import UTC, datetime, timedelta
from decimal import Decimal

import jwt
from app.core.config import settings
from app.core.enums import UserRole
from app.models.auction import Auction
from app.models.bid import Bid
from app.models.user import User


def _active_auction(factory, *, base="100.00", end_delta=3600):
    with factory() as db:
        now = datetime.now(UTC)
        row = Auction(product_id=1, status_id=4, base_price=Decimal(base), minimum_increment=Decimal("5.00"),
                      start_date=now-timedelta(minutes=1), end_date=now+timedelta(seconds=end_delta))
        db.add(row); db.commit(); return row.auction_id


def _token(user_id=3, role="POSTOR"):
    return jwt.encode({"sub": str(user_id), "role": role, "exp": 4102444800}, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def test_valid_bid_and_first_bid_at_base(auction_api):
    client, factory = auction_api
    aid = _active_auction(factory)
    with factory() as db:
        user = db.get(User, 3); user.bid_policy_accepted_at = datetime.now(UTC); db.commit()
    response = client.post(f"/api/v1/auctions/{aid}/bids", json={"amount": "100.00"}, headers={"Authorization": f"Bearer {_token()}"})
    assert response.status_code == 201, response.text
    assert response.json()["is_leader"] and response.json()["auction_id"] == aid


def test_bid_minimum_equal_leader_self_and_my_auctions(auction_api):
    client, factory = auction_api
    aid = _active_auction(factory)
    with factory() as db:
        db.get(User, 3).bid_policy_accepted_at = datetime.now(UTC)
        db.add(Bid(auction_id=aid, participant_id=2, amount=Decimal("100.00"))); db.commit()
    headers={"Authorization": f"Bearer {_token()}"}
    assert client.post(f"/api/v1/auctions/{aid}/bids", json={"amount":"104.99"}, headers=headers).status_code == 422
    # El mismo monto que el líder también queda bajo el mínimo (líder + incremento).
    assert client.post(f"/api/v1/auctions/{aid}/bids", json={"amount":"100.00"}, headers=headers).status_code == 422
    assert client.post(f"/api/v1/auctions/{aid}/bids", json={"amount":"105.00"}, headers=headers).status_code == 201
    mine=client.get("/api/v1/me/auctions", headers=headers)
    assert mine.status_code == 200 and mine.json()["items"][0]["my_highest_bid"] == "105.00"


def test_self_leader_policy_role_token_and_state_errors(auction_api):
    client, factory = auction_api
    aid=_active_auction(factory)
    with factory() as db:
        db.get(User, 3).bid_policy_accepted_at = datetime.now(UTC)
        db.add(Bid(auction_id=aid, participant_id=3, amount=Decimal("100.00"))); db.commit()
    headers={"Authorization": f"Bearer {_token()}"}
    assert client.post(f"/api/v1/auctions/{aid}/bids", json={"amount":"105.00"}, headers=headers).status_code == 409
    with factory() as db:
        db.get(User,3).bid_policy_accepted_at=None; db.commit()
    with factory() as db:
        db.query(Bid).filter(Bid.auction_id==aid).delete(); db.commit()
    assert client.post(f"/api/v1/auctions/{aid}/bids", json={"amount":"100.00"}, headers=headers).status_code == 403
    assert client.post(f"/api/v1/auctions/{aid}/bids", json={"amount":"100.00"}, headers={"Authorization":f"Bearer {_token(1,'VENDEDOR')}"}).status_code == 403
    client.headers.pop("Authorization")
    assert client.post(f"/api/v1/auctions/{aid}/bids", json={"amount":"100.00"}).status_code == 401
    with factory() as db:
        row=db.get(Auction,aid); row.end_date=datetime.now(UTC)-timedelta(seconds=1); db.commit()
    assert client.post(f"/api/v1/auctions/{aid}/bids", json={"amount":"100.00"}, headers=headers).status_code == 409


def test_bid_rejects_non_active_and_invalid_precision(auction_api):
    client,factory=auction_api; aid=_active_auction(factory)
    with factory() as db:
        db.get(User,3).bid_policy_accepted_at=datetime.now(UTC)
        row=db.get(Auction,aid); row.start_date=datetime.now(UTC)+timedelta(hours=1); db.commit()
    headers={"Authorization":f"Bearer {_token()}"}
    assert client.post(f"/api/v1/auctions/{aid}/bids",json={"amount":"100.00"},headers=headers).status_code==409
    assert client.post(f"/api/v1/auctions/{aid}/bids",json={"amount":"100.001"},headers=headers).status_code==422
