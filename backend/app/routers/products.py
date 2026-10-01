from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.orm import Session

from app.api.deps import require_role
from app.core.enums import UserRole
from app.db.session import get_db
from app.models.user import User
from app.schemas.products import CategoryResponse, ProductCreate, ProductDeleteResponse, ProductPatch, ProductResponse
from app.services import products as product_service

router = APIRouter()


@router.get("/categories", response_model=list[CategoryResponse], tags=["categories"])
def categories(session: Session = Depends(get_db)):
    return product_service.list_categories(session)


@router.post("/products", response_model=ProductResponse, status_code=status.HTTP_201_CREATED, tags=["products"])
def create_product(payload: ProductCreate, session: Session = Depends(get_db), seller: User = Depends(require_role(UserRole.VENDEDOR))):
    return product_service.create(session, seller, payload)


@router.get("/products", response_model=list[ProductResponse], tags=["products"])
def list_products(brand: str | None = Query(default=None), category_id: int | None = Query(default=None, gt=0), name: str | None = Query(default=None), session: Session = Depends(get_db), seller: User = Depends(require_role(UserRole.VENDEDOR))):
    return product_service.list_mine(session, seller, brand, category_id, name)


@router.get("/products/{product_id}", response_model=ProductResponse, tags=["products"])
def get_product(product_id: int, session: Session = Depends(get_db), seller: User = Depends(require_role(UserRole.VENDEDOR))):
    return product_service.get_mine(session, seller, product_id)


@router.patch("/products/{product_id}", response_model=ProductResponse, tags=["products"])
def update_product(product_id: int, payload: ProductPatch, session: Session = Depends(get_db), seller: User = Depends(require_role(UserRole.VENDEDOR))):
    return product_service.update(session, seller, product_id, payload)


@router.delete("/products/{product_id}", response_model=ProductDeleteResponse, tags=["products"])
def delete_product(product_id: int, session: Session = Depends(get_db), seller: User = Depends(require_role(UserRole.VENDEDOR))):
    return product_service.delete(session, seller, product_id)


@router.post("/products/{product_id}/reactivate", response_model=ProductResponse, tags=["products"])
def reactivate_product(product_id: int, session: Session = Depends(get_db), seller: User = Depends(require_role(UserRole.VENDEDOR))):
    return product_service.reactivate(session, seller, product_id)
