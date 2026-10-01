from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.user import User


def get_by_id(session: Session, user_id: int) -> User | None:
    return session.get(User, user_id)


def get_by_email(session: Session, email: str) -> User | None:
    return session.scalar(select(User).where(User.email == email))


def get_by_alias(session: Session, alias: str) -> User | None:
    return session.scalar(select(User).where(User.alias == alias))


def add_user(session: Session, user: User) -> User:
    session.add(user)
    return user
