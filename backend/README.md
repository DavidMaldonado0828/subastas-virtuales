# Backend — Sistema de Subastas Virtuales

Esqueleto inicial de FastAPI y SQLAlchemy para PostgreSQL en Neon.

## Requisitos

- Python 3.10 o superior.
- `backend/.env` con `DATABASE_URL` (conexión directa Neon para Alembic) y `DATABASE_URL_POOLED` (conexión pooled para FastAPI). Usa `.env.example` como referencia; no guardes credenciales en el repositorio.

Ambas variables pueden usar el formato `postgresql://...`. La configuración las convierte a `postgresql+psycopg://...` al crear la conexión. Asegúrate de incluir `sslmode=require`.

La autenticación usa `JWT_SECRET_KEY` y `ACCESS_TOKEN_EXPIRE_MINUTES` (60 por defecto). Define una clave secreta fuera del repositorio antes de probar el login; los registros de Postor deben incluir la aceptación de la política. Las contraseñas admiten entre 8 y 128 caracteres.

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

Verifica el proceso en `http://127.0.0.1:8000/health`. En `http://127.0.0.1:8000/docs` están disponibles los endpoints de autenticación; todavía no hay endpoints de negocio.

## Autenticación implementada

En Swagger (`/docs`), usa `POST /api/v1/auth/register` para crear un Vendedor o Postor y `POST /api/v1/auth/login` para obtener el JWT. El alta de Postor requiere `accept_bid_policy: true`; Admin no se registra por API. El JWT identifica el rol y vence según `ACCESS_TOKEN_EXPIRE_MINUTES` (60 por defecto). Aún no hay rutas de negocio protegidas en la aplicación; la autenticación y los guardas de rol/pertenencia se verifican en pytest.

Para crear las tres cuentas iniciales, define `SEED_ADMIN_PASSWORD`, `SEED_SELLER_PASSWORD` y `SEED_POSTOR_PASSWORD` en el entorno del proceso (o en `.env`) y ejecuta:

```powershell
python -m scripts.seed_users
```

El seed es idempotente por email y nunca imprime las contraseñas.
