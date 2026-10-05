#Este archivo contiene la configuración de la base de datos.
from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings

#El motor permite crear el tunel de comunicación con la base de datos.
engine = create_engine(settings.database_url_pooled, pool_pre_ping=True)
#La clase sessionmaker se utiliza para crear instancias de sesión que permiten interactuar con la base de datos. Se configura para no realizar autoflush y no expirar los objetos al hacer commit.
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)

#Genera una sesión de base de datos que se puede utilizar en las rutas de FastAPI. 
def get_db() -> Generator[Session, None, None]:
    with SessionLocal() as session:
        yield session
