from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.category import Category
from app.models.status import Status, StatusApplicability
from app.models.product import Product


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


def list_admin(session: Session) -> list[tuple[Category, str, int]]:
    count = select(func.count(Product.product_id)).where(
        Product.category_id == Category.category_id
    ).scalar_subquery()
    rows = session.execute(
        select(Category, Status.code, count).join(Status, Status.status_id == Category.status_id)
        .order_by(func.lower(Category.name), Category.name)
    )
    return [(category, code, int(product_count)) for category, code, product_count in rows]


def name_exists_normalized(session: Session, name: str, *, exclude_id: int | None = None) -> bool:
    query = select(Category.name, Category.category_id)
    if exclude_id is not None:
        query = query.where(Category.category_id != exclude_id)
    normalized = "".join(name.split()).casefold()
    return any("".join(existing.split()).casefold() == normalized
               for existing, _category_id in session.execute(query))


def add(session: Session, category: Category) -> Category:
    session.add(category)
    return category


def get_for_update(session: Session, category_id: int) -> Category | None:
    return session.scalar(select(Category).where(Category.category_id == category_id).with_for_update())


def get_by_name(session: Session, name: str) -> Category | None:
    return session.scalar(select(Category).where(Category.name == name))
