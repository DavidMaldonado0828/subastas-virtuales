from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.status import Status, StatusApplicability
from app.models.user import User


def get_by_id(session: Session, user_id: int) -> User | None:
    return session.get(User, user_id)


def get_by_email(session: Session, email: str) -> User | None:
    return session.scalar(select(User).where(User.email == email))


def get_by_alias(session: Session, alias: str) -> User | None:
    return session.scalar(select(User).where(User.alias == alias))


def get_status_for_entity(session: Session, code: str, entity_type: str) -> Status | None:
    statement = (
        select(Status)
        .join(StatusApplicability, StatusApplicability.status_id == Status.status_id)
        .where(Status.code == code, StatusApplicability.entity_type == entity_type)
    )
    return session.scalar(statement)


def get_status_code(session: Session, status_id: int) -> str | None:
    status_record = session.get(Status, status_id)
    return status_record.code if status_record else None


def add_user(session: Session, user: User) -> User:
    session.add(user)
    return user
