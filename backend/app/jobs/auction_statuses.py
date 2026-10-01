from datetime import UTC, datetime

from sqlalchemy.orm import Session, sessionmaker

from app.models.auction import Auction
from app.repositories import auctions as auction_repository
from app.services.auctions import calculate_status
from app.services.status_history import record_status_change


def update_auction_statuses(
    session_factory: sessionmaker[Session], *, now: datetime | None = None
) -> int:
    """Apply date-based auction transitions and append history atomically."""
    current_time = now or datetime.now(UTC)
    with session_factory() as session:
        statuses = auction_repository.get_status_ids(session)
        auctions = auction_repository.open_for_scheduling(session, for_update=True)
        changed = 0
        for auction in auctions:
            current_code = auction_repository.get_status_code(session, auction.status_id)
            target_code = calculate_status(auction.start_date, auction.end_date, current_time)
            if current_code == "PROGRAMADA" and target_code in ("ACTIVA", "CERRADA"):
                auction.status_id = statuses["ACTIVA"]
                auction.updated_at = current_time
                record_status_change(session, entity_type="AUCTION", entity_id=auction.auction_id,
                    old_status_code="PROGRAMADA", new_status_code="ACTIVA", changed_by=None,
                    event_source="SCHEDULER")
                current_code = "ACTIVA"
                changed += 1
            if current_code == "ACTIVA" and target_code == "CERRADA":
                auction.status_id = statuses["CERRADA"]
                auction.updated_at = current_time
                record_status_change(session, entity_type="AUCTION", entity_id=auction.auction_id,
                    old_status_code="ACTIVA", new_status_code="CERRADA", changed_by=None,
                    event_source="SCHEDULER")
                changed += 1
        session.commit()
        return changed
