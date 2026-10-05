from contextlib import asynccontextmanager

from apscheduler.schedulers.background import BackgroundScheduler
from fastapi import FastAPI

from app.core.config import settings
from app.db.session import SessionLocal
from app.jobs.auction_statuses import update_auction_statuses
from app.routers.auth import router as auth_router
from app.routers.products import router as products_router
from app.routers.auctions import router as auctions_router
from app.routers.me import router as me_router
from app.routers.admin import router as admin_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    scheduler = None
    if settings.scheduler_enabled:
        scheduler = BackgroundScheduler(timezone="UTC")
        scheduler.add_job(update_auction_statuses, "interval", minutes=1,
            args=[SessionLocal], id="auction-statuses", replace_existing=True)
        scheduler.start()
    try:
        yield
    finally:
        if scheduler is not None:
            scheduler.shutdown(wait=False)


app = FastAPI(title="Sistema de Subastas Virtuales API", version="0.1.0", lifespan=lifespan)
app.include_router(auth_router, prefix="/api/v1")
app.include_router(products_router, prefix="/api/v1")
app.include_router(auctions_router, prefix="/api/v1")
app.include_router(me_router, prefix="/api/v1")
app.include_router(admin_router, prefix="/api/v1")


@app.get("/health", tags=["health"])
def health_check() -> dict[str, str]:
    return {"status": "ok"}
