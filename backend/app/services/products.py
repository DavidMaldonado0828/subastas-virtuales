from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.enums import EntityType
from app.models.category import Category
from app.models.product import Product
from app.models.user import User
from app.repositories import categories as category_repository
from app.repositories import products as product_repository
from app.repositories import statuses as status_repository
from app.schemas.products import ProductCreate, ProductPatch
from app.services.status_history import record_status_change


def _category(session: Session, category_id: int) -> Category:
    category = category_repository.get_by_id(session, category_id)
    if category is None or not category_repository.is_active(session, category):
        raise HTTPException(status_code=422, detail="La categoría no existe o está desactivada.")
    return category


def _owned(session: Session, product_id: int, seller_id: int) -> Product:
    product = product_repository.get_owned(session, product_id, seller_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Producto no encontrado.")
    return product


def create(session: Session, seller: User, payload: ProductCreate) -> Product:
    _category(session, payload.category_id)
    active_status = status_repository.get_status_for_entity(session, "ACTIVO", EntityType.PRODUCT.value)
    if active_status is None:
        raise HTTPException(status_code=503, detail="El catálogo de estados no está inicializado.")
    product = Product(seller_id=seller.user_id, status_id=active_status.status_id,
        **payload.model_dump())
    product_repository.add(session, product)
    session.commit()
    session.refresh(product)
    return product


def list_mine(session: Session, seller: User, brand: str | None, category_id: int | None, name: str | None) -> list[Product]:
    return product_repository.list_owned(session, seller.user_id, brand, category_id, name)


def get_mine(session: Session, seller: User, product_id: int) -> Product:
    return _owned(session, product_id, seller.user_id)


def update(session: Session, seller: User, product_id: int, payload: ProductPatch) -> Product:
    product = _owned(session, product_id, seller.user_id)
    changes = payload.model_dump(exclude_unset=True)
    if not changes:
        raise HTTPException(status_code=422, detail="Debe indicar al menos un campo.")
    locked_fields = set(changes) - {"description", "image_url"}
    if locked_fields and product_repository.ever_active_or_closed(session, product_id):
        raise HTTPException(status_code=409, detail="Solo puede editar descripción e imagen del producto asociado a una subasta Activa o Cerrada.")
    for field in ("name", "description", "category_id"):
        if field in changes and changes[field] is None:
            raise HTTPException(status_code=422, detail=f"{field} no puede ser nulo.")
    if "category_id" in changes:
        _category(session, changes["category_id"])
    for field, value in changes.items():
        setattr(product, field, value)
    product.updated_at = datetime.now(UTC)
    session.commit()
    session.refresh(product)
    return product


def delete(session: Session, seller: User, product_id: int) -> dict[str, int | str | None]:
    product = _owned(session, product_id, seller.user_id)
    auctions = product_repository.get_auctions(session, product_id)
    blocking = [auction for auction in auctions if status_repository.get_status_code(session, auction.status_id) in ("ACTIVA", "CERRADA")]
    if blocking:
        raise HTTPException(status_code=409, detail="No se puede eliminar el producto porque tiene una subasta ACTIVA o CERRADA.")
    if not auctions:
        session.delete(product)
        session.commit()
        return {"product_id": product_id, "result": "DELETED", "status": None}
    deactivated = status_repository.get_status_for_entity(session, "DESACTIVADO", EntityType.PRODUCT.value)
    if deactivated is None:
        raise HTTPException(status_code=503, detail="El catálogo de estados no está inicializado.")
    old_status = status_repository.get_status_code(session, product.status_id)
    product.status_id = deactivated.status_id
    product.updated_at = datetime.now(UTC)
    record_status_change(session, entity_type="PRODUCT", entity_id=product_id,
        old_status_code=old_status, new_status_code="DESACTIVADO", changed_by=seller,
        event_source="API_DEACTIVATE_PRODUCT")
    for auction in auctions:
        old_auction_status = status_repository.get_status_code(session, auction.status_id)
        cancelled = status_repository.get_status_for_entity(session, "CANCELADA", EntityType.AUCTION.value)
        if old_auction_status != "PROGRAMADA" or cancelled is None:
            session.rollback()
            raise HTTPException(status_code=503, detail="No fue posible actualizar el estado de la subasta.")
        auction.status_id = cancelled.status_id
        record_status_change(session, entity_type="AUCTION", entity_id=auction.auction_id,
            old_status_code="PROGRAMADA", new_status_code="CANCELADA", changed_by=seller,
            event_source="API_DEACTIVATE_PRODUCT")
    session.commit()
    return {"product_id": product_id, "result": "DEACTIVATED", "status": "DESACTIVADO"}


def reactivate(session: Session, seller: User, product_id: int) -> Product:
    product = _owned(session, product_id, seller.user_id)
    current_status = status_repository.get_status_code(session, product.status_id)
    if current_status != "DESACTIVADO":
        raise HTTPException(status_code=409, detail="Solo se pueden reactivar productos en estado DESACTIVADO.")
    category = category_repository.get_by_id(session, product.category_id)
    if category is None or not category_repository.is_active(session, category):
        raise HTTPException(status_code=409, detail="No se puede reactivar el producto porque su categoría está desactivada.")
    active = status_repository.get_status_for_entity(session, "ACTIVO", EntityType.PRODUCT.value)
    if active is None:
        raise HTTPException(status_code=503, detail="El catálogo de estados no está inicializado.")
    product.status_id = active.status_id
    product.updated_at = datetime.now(UTC)
    record_status_change(session, entity_type="PRODUCT", entity_id=product_id,
        old_status_code="DESACTIVADO", new_status_code="ACTIVO", changed_by=seller,
        event_source="USER")
    session.commit()
    session.refresh(product)
    return product


def list_categories(session: Session) -> list[Category]:
    return category_repository.list_active(session)
