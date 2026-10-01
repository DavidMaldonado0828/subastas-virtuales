from fastapi import FastAPI

from app.routers.auth import router as auth_router
from app.routers.products import router as products_router
from app.routers.auctions import router as auctions_router

app = FastAPI(title="Sistema de Subastas Virtuales API", version="0.1.0")
app.include_router(auth_router, prefix="/api/v1")
app.include_router(products_router, prefix="/api/v1")
app.include_router(auctions_router, prefix="/api/v1")


@app.get("/health", tags=["health"])
def health_check() -> dict[str, str]:
    return {"status": "ok"}
