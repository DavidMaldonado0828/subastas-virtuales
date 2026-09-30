from pathlib import Path

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parents[2]


def to_psycopg_url(url: str) -> str:
    """Normalize Neon's postgresql:// URL for the Psycopg 3 SQLAlchemy driver."""
    if url.startswith("postgresql://"):
        return "postgresql+psycopg://" + url.removeprefix("postgresql://")
    if url.startswith("postgres://"):
        return "postgresql+psycopg://" + url.removeprefix("postgres://")
    return url


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    database_url: str = Field(repr=False)
    database_url_pooled: str = Field(repr=False)

    @field_validator("database_url", "database_url_pooled")
    @classmethod
    def normalize_postgres_url(cls, value: str) -> str:
        return to_psycopg_url(value)


settings = Settings()
