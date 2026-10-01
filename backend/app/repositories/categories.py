from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.category import Category
from app.models.status import Status, StatusApplicability


def get_by_id(session: Session, category_id: int) -> Category | None:
    return session.get(Category, category_id)


def is_active(session: Session, category: Category) -> bool:
    return bool(session.scalar(select(Status.status_id).where(
        Status.status_id == category.status_id, Status.code == "ACTIVO", Status.enabled.is_(True)
    ).join(StatusApplicability, StatusApplicability.status_id == Status.status_id).where(
        StatusApplicability.entity_type == "CATEGORY"
    )))


def list_active(session: Session) -> list[Category]:
    return list(session.scalars(select(Category).join(Status).where(
        Status.code == "ACTIVO", Status.enabled.is_(True)
    ).order_by(Category.name)))


def get_by_name(session: Session, name: str) -> Category | None:
    return session.scalar(select(Category).where(Category.name == name))
