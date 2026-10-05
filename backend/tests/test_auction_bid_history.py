from datetime import UTC, datetime, timedelta
from decimal import Decimal

import jwt
from app.core.config import settings
from app.jobs.auction_statuses import update_auction_statuses
from app.models.auction import Auction
from app.models.bid import Bid
from app.models.status_history import StatusHistory


def _token(user_id: int, role: str = "VENDEDOR") -> str:
    return jwt.encode({"sub": str(user_id), "role": role, "exp": 4102444800}, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def _closed_auction(factory, *, with_bids: bool, product_id: int = 1) -> int:
    with factory() as db:
        now = datetime.now(UTC)
        auction = Auction(product_id=product_id, status_id=4, base_price=Decimal("50.00"),
                          minimum_increment=Decimal("1.00"), start_date=now-timedelta(hours=2),
                          end_date=now-timedelta(minutes=1))
        db.add(auction); db.flush()
        if with_bids:
            # Same highest amount: earliest bid wins; IDs also provide a deterministic final tie break.
            db.add_all([
                Bid(auction_id=auction.auction_id, participant_id=3, amount=Decimal("90.00"), bid_date=now-timedelta(minutes=4)),
                Bid(auction_id=auction.auction_id, participant_id=1, amount=Decimal("90.00"), bid_date=now-timedelta(minutes=3)),
                Bid(auction_id=auction.auction_id, participant_id=2, amount=Decimal("70.00"), bid_date=now-timedelta(minutes=2)),
                Bid(auction_id=auction.auction_id, participant_id=3, amount=Decimal("60.00"), bid_date=now-timedelta(minutes=1)),
                Bid(auction_id=auction.auction_id, participant_id=1, amount=Decimal("55.00"), bid_date=now-timedelta(seconds=50)),
                Bid(auction_id=auction.auction_id, participant_id=2, amount=Decimal("52.00"), bid_date=now-timedelta(seconds=40)),
            ])
        db.commit()
        return auction.auction_id


def test_cron_closes_with_winner_and_tie_breaks_by_oldest_bid(auction_api):
    client, factory = auction_api
    auction_id = _closed_auction(factory, with_bids=True)
    assert update_auction_statuses(factory) == 1
    detail = client.get(f"/api/v1/auctions/{auction_id}").json()
    assert detail["status"] == "CERRADA"
    assert detail["winner"] == {"alias": "bidder", "amount": "90.00"}
    with factory() as db:
        events = db.query(StatusHistory).filter_by(entity_type="AUCTION", entity_id=auction_id).all()
        assert [(e.old_status_code, e.new_status_code, e.event_source) for e in events] == [("ACTIVA", "CERRADA", "SCHEDULER")]
    assert update_auction_statuses(factory) == 0


def test_cron_closes_without_bids_and_records_idempotently(auction_api):
    client, factory = auction_api
    auction_id = _closed_auction(factory, with_bids=False)
    assert update_auction_statuses(factory) == 1
    detail = client.get(f"/api/v1/auctions/{auction_id}").json()
    assert detail["status"] == "FINALIZADA_SIN_GANADOR" and detail["winner"] is None
    with factory() as db:
        events = db.query(StatusHistory).filter_by(entity_type="AUCTION", entity_id=auction_id).all()
        assert [(e.old_status_code, e.new_status_code, e.event_source) for e in events] == [("ACTIVA", "FINALIZADA_SIN_GANADOR", "SCHEDULER")]
    assert update_auction_statuses(factory) == 0


def test_cron_records_both_transitions_when_scheduled_auction_is_already_expired(auction_api):
    _client, factory = auction_api
    with factory() as db:
        now = datetime.now(UTC)
        auction = Auction(product_id=1, status_id=3, base_price=Decimal("50.00"), minimum_increment=Decimal("1.00"),
                          start_date=now-timedelta(hours=2), end_date=now-timedelta(minutes=1))
        db.add(auction); db.commit(); auction_id = auction.auction_id
    assert update_auction_statuses(factory) == 2
    with factory() as db:
        events = db.query(StatusHistory).filter_by(entity_type="AUCTION", entity_id=auction_id).order_by(StatusHistory.history_id).all()
        assert [(event.old_status_code, event.new_status_code) for event in events] == [
            ("PROGRAMADA", "ACTIVA"), ("ACTIVA", "FINALIZADA_SIN_GANADOR")]


def test_public_top_five_owner_full_other_seller_limited_and_private_fields_hidden(auction_api):
    client, factory = auction_api
    auction_id = _closed_auction(factory, with_bids=True)
    # Add another four bids so the full history contains ten rows.
    with factory() as db:
        now = datetime.now(UTC)
        for amount in ("51", "50", "49", "48"):
            db.add(Bid(auction_id=auction_id, participant_id=3, amount=Decimal(amount), bid_date=now))
        db.commit()

    client.headers.pop("Authorization")
    public = client.get(f"/api/v1/auctions/{auction_id}/bids")
    assert public.status_code == 200 and public.json()["limit"] == 5
    assert len(public.json()["items"]) == 5
    assert [row["amount"] for row in public.json()["items"]] == ["90.00", "90.00", "70.00", "60.00", "55.00"]
    assert all(set(row) == {"bidder_alias", "amount", "bid_date"} for row in public.json()["items"])
    assert not any(private in public.text for private in ("email", "phone_number", "address", "password_hash"))

    owner = client.get(f"/api/v1/auctions/{auction_id}/bids?limit=7&offset=2", headers={"Authorization": f"Bearer {_token(1)}"})
    assert owner.status_code == 200 and owner.json()["limit"] == 7 and owner.json()["offset"] == 2
    assert len(owner.json()["items"]) == 7
    other = client.get(f"/api/v1/auctions/{auction_id}/bids?limit=100&offset=3", headers={"Authorization": f"Bearer {_token(2)}"})
    assert other.status_code == 200 and other.json()["limit"] == 5 and other.json()["offset"] == 0
    assert len(other.json()["items"]) == 5
    assert client.get(f"/api/v1/auctions/999/bids").status_code == 404


def test_bid_and_status_history_reconstruct_auction_timeline(auction_api):
    _client, factory = auction_api
    auction_id = _closed_auction(factory, with_bids=True)
    update_auction_statuses(factory)
    with factory() as db:
        bids = db.query(Bid).filter_by(auction_id=auction_id).order_by(Bid.bid_date, Bid.bid_id).all()
        events = db.query(StatusHistory).filter_by(entity_type="AUCTION", entity_id=auction_id).order_by(StatusHistory.history_id).all()
        assert len(bids) == 6
        assert [bid.amount for bid in bids] == [Decimal("90.00"), Decimal("90.00"), Decimal("70.00"), Decimal("60.00"), Decimal("55.00"), Decimal("52.00")]
        assert [(event.old_status_code, event.new_status_code) for event in events] == [("ACTIVA", "CERRADA")]
        assert events[0].event_source == "SCHEDULER"
