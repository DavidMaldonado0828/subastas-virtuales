from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.status import Status, StatusApplicability


def get_status_for_entity(session: Session, code: str, entity_type: str) -> Status | None:
    return session.scalar(select(Status).join(StatusApplicability).where(
        Status.code == code, StatusApplicability.entity_type == entity_type
    ))


def get_status_code(session: Session, status_id: int) -> str | None:
    status = session.get(Status, status_id)
    return status.code if status else None
