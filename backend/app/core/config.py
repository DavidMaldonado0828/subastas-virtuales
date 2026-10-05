#Este archivo contiene la configuración de la aplicación, incluyendo la URL de la base de datos y las configuraciones relacionadas con JWT y el programador de tareas.
from pathlib import Path

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

#Identifica la ruta del directorio raíz del backend para cargar el archivo .env y otros recursos.
BACKEND_DIR = Path(__file__).resolve().parents[2]

#Configura la URL de la base de datos para que sea compatible con el controlador Psycopg 3 de SQLAlchemy, normalizando las URL de PostgreSQL.
def to_psycopg_url(url: str) -> str:
    """Normaliza la URL postgresql:// de Neon para el driver Psycopg 3 de SQLAlchemy."""
    if url.startswith("postgresql://"):
        return "postgresql+psycopg://" + url.removeprefix("postgresql://")
    if url.startswith("postgres://"):
        return "postgresql+psycopg://" + url.removeprefix("postgres://")
    return url

#Perimte la configuración de la aplicación a través de variables de entorno.
class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    database_url: str = Field(repr=False)
    database_url_pooled: str = Field(repr=False)
    jwt_secret_key: str | None = Field(default=None, repr=False)
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = Field(default=60, gt=0)
    scheduler_enabled: bool = True
    cors_origins: str = "http://localhost:4200"

    @field_validator("database_url", "database_url_pooled")
    @classmethod
    def normalize_postgres_url(cls, value: str) -> str:
        return to_psycopg_url(value)

#Se crea una instancia de la clase Settings para acceder a la configuración de la aplicación.
settings = Settings()
