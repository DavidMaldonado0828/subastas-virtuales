from app.models.status_history import StatusHistory
from app.models.user import User
from sqlalchemy.orm import Session


def record_status_change(
    session: Session,
    *,
    entity_type: str,
    entity_id: int,
    old_status_code: str | None,
    new_status_code: str,
    changed_by: User | int | None,
    event_source: str,
) -> StatusHistory:
    """Add one append-only history event; caller controls the transaction."""
    changed_by_id = changed_by.user_id if isinstance(changed_by, User) else changed_by
    entry = StatusHistory(
        entity_type=entity_type,
        entity_id=entity_id,
        old_status_code=old_status_code,
        new_status_code=new_status_code,
        changed_by=changed_by_id,
        event_source=event_source,
    )
    session.add(entry)
    return entry
