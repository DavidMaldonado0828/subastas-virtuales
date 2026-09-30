# Backend — Sistema de Subastas Virtuales

Esqueleto inicial de FastAPI y SQLAlchemy para PostgreSQL en Neon.

## Requisitos

- Python 3.10 o superior.
- `backend/.env` con `DATABASE_URL` (conexión directa Neon para Alembic) y `DATABASE_URL_POOLED` (conexión pooled para FastAPI). Usa `.env.example` como referencia; no guardes credenciales en el repositorio.

Ambas variables pueden usar el formato `postgresql://...`. La configuración las convierte a `postgresql+psycopg://...` al crear la conexión. Asegúrate de incluir `sslmode=require`.

## Preparación (PowerShell desde `backend/`)

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

## Migraciones

Alembic toma `DATABASE_URL` (conexión directa, no pooled) desde `.env`. Desde `backend/` ejecuta:

```powershell
alembic upgrade head
```

La migración inicial crea las tablas del modelo y carga los estados junto con su aplicabilidad por entidad.

## Iniciar la aplicación

FastAPI utiliza `DATABASE_URL_POOLED` para su engine:

```powershell
uvicorn app.main:app --reload
```

Verifica el proceso en `http://127.0.0.1:8000/health`. La documentación interactiva vacía está disponible en `http://127.0.0.1:8000/docs`; todavía no hay endpoints de negocio.
