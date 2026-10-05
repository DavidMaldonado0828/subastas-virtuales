from contextlib import asynccontextmanager

from apscheduler.schedulers.background import BackgroundScheduler
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.db.session import SessionLocal
from app.jobs.auction_statuses import update_auction_statuses
from app.routers.auth import router as auth_router
from app.routers.products import router as products_router
from app.routers.auctions import router as auctions_router
from app.routers.me import router as me_router
from app.routers.admin import router as admin_router

#Este archivo contiene la configuración principal de la aplicación FastAPI, incluyendo la inicialización de la aplicación, la configuración de CORS, el registro de rutas y la definición del endpoint de verificación de estado.
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

#Se crea una instancia de FastAPI con el título y la versión de la API, y se define la función de vida útil que maneja la inicialización y finalización del programador de tareas.
app = FastAPI(title="Sistema de Subastas Virtuales API", version="0.1.0", lifespan=lifespan)


#Esta función agrega el middleware CORS a la aplicación FastAPI, permitiendo solicitudes desde los orígenes especificados en la configuración.
def add_cors_middleware(app: FastAPI, origins: str) -> None:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[origin.strip() for origin in origins.split(",") if origin.strip()],
        allow_credentials=False,
        allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type"],
    )

#Se añade el middleware CORS a la aplicación FastAPI utilizando los orígenes especificados en la configuración, y se registran las rutas de autenticación, productos, subastas, información del usuario y administración bajo el prefijo "/api/v1".
add_cors_middleware(app, settings.cors_origins)
app.include_router(auth_router, prefix="/api/v1")
app.include_router(products_router, prefix="/api/v1")
app.include_router(auctions_router, prefix="/api/v1")
app.include_router(me_router, prefix="/api/v1")
app.include_router(admin_router, prefix="/api/v1")

#Se define un endpoint de verificación de estado en la ruta "/health" que devuelve un diccionario indicando que el estado de la aplicación es "ok".
@app.get("/health", tags=["health"])
def health_check() -> dict[str, str]:
    return {"status": "ok"}
