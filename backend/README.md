# Backend — Sistema de Subastas Virtuales

API MVP construida con FastAPI, Pydantic v2, SQLAlchemy 2 y PostgreSQL. Los endpoints implementados cubren autenticación, productos del vendedor, catálogo y detalle de subastas, pujas e historial, gestión administrativa de usuarios/subastas y consulta de subastas del vendedor.

## Requisitos y configuración

- Python 3.10 o superior.
- PostgreSQL accesible desde el entorno.
- Configura estas variables en `backend/.env` (solo nombres; no guardes credenciales en el repositorio):

| Variable | Uso |
| --- | --- |
| `DATABASE_URL` | Conexión directa a PostgreSQL, usada por Alembic. |
| `DATABASE_URL_POOLED` | Conexión pooled usada por la aplicación. |
| `JWT_SECRET_KEY` | Clave para firmar y validar JWT. |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | Duración del token de acceso. |
| `SCHEDULER_ENABLED` | Activa o desactiva el scheduler de estados. |
| `SEED_ADMIN_PASSWORD` | Contraseña del usuario administrador creado por el seed. |

## Instalación y ejecución

Ejecuta desde `backend/` en PowerShell:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
alembic upgrade head
python -m scripts.seed_users
uvicorn app.main:app --reload
```

El seed requiere `SEED_ADMIN_PASSWORD` y crea el administrador inicial y categorías de muestra; es idempotente. La API queda disponible en `http://127.0.0.1:8000`, la documentación interactiva en `/docs` y el chequeo de salud en `/health`.

### Datos de demostración

Después de crear los usuarios de demo (el script no crea usuarios), carga productos y subastas de muestra con fechas relativas a UTC:

```powershell
python -m scripts.seed_demo
```

El seed requiere los alias existentes `carlos_antiguedades` (VENDEDOR), `mafe_gomez`, `juanse_mtz` y `David23` (POSTOR), y `admin_subastas` (ADMIN). Si falta alguno o su rol no coincide, informa y termina sin crearlo. Los productos se identifican por nombres reservados y una marca en la descripción para evitar duplicados.

Para borrar únicamente datos identificables como creados por este script:

```powershell
python -m scripts.seed_demo --reset
```

El programa solicita escribir exactamente `BORRAR DEMO`. Si hay actividad o historial ajeno al seed asociado a un registro demo, lo conserva y lo informa.

## Endpoints implementados

Las rutas de negocio están bajo `/api/v1`. Los roles son `VENDEDOR`, `POSTOR` y `ADMIN`.

| Método | Ruta | Rol requerido |
| --- | --- | --- |
| `POST` | `/api/v1/auth/register` | Público (registro de `VENDEDOR` o `POSTOR`; no registra `ADMIN`) |
| `POST` | `/api/v1/auth/login` | Público |
| `GET` | `/api/v1/categories` | Público |
| `POST` | `/api/v1/products` | `VENDEDOR` |
| `GET` | `/api/v1/products` | `VENDEDOR` (lista productos propios; filtros `brand`, `category_id`, `name`) |
| `GET` | `/api/v1/products/{product_id}` | `VENDEDOR` propietario |
| `PATCH` | `/api/v1/products/{product_id}` | `VENDEDOR` propietario |
| `DELETE` | `/api/v1/products/{product_id}` | `VENDEDOR` propietario |
| `POST` | `/api/v1/products/{product_id}/reactivate` | `VENDEDOR` propietario |
| `GET` | `/api/v1/auctions` | Público; filtro opcional `status` |
| `GET` | `/api/v1/auctions/{auction_id}` | Público |
| `POST` | `/api/v1/auctions` | `VENDEDOR` |
| `PATCH` | `/api/v1/auctions/{auction_id}` | `VENDEDOR` propietario |
| `POST` | `/api/v1/auctions/{auction_id}/bids` | `POSTOR` |
| `GET` | `/api/v1/auctions/{auction_id}/bids` | Público: primeros 5 registros; `VENDEDOR` propietario o `ADMIN`: paginación completa |
| `GET` | `/api/v1/me/auctions` | `POSTOR`; filtro opcional `status` |
| `GET` | `/api/v1/me/seller/auctions` | `VENDEDOR` |
| `GET` | `/api/v1/admin/auctions` | `ADMIN`; filtros opcionales `status`, `limit`, `offset` |
| `POST` | `/api/v1/admin/auctions/{auction_id}/cancel` | `ADMIN` |
| `GET` | `/api/v1/admin/users` | `ADMIN`; búsqueda `search` por alias/email y filtro opcional `status` |
| `PATCH` | `/api/v1/admin/users/{user_id}/status` | `ADMIN` |
| `GET` | `/health` | Público |

El catálogo público acepta `PROGRAMADA`, `ACTIVA`, `CERRADA` o `FINALIZADA_SIN_GANADOR` en `status`. Sin filtro devuelve únicamente subastas `ACTIVA` y `PROGRAMADA`; nunca incluye `CANCELADA`. El servidor ordena por estado y fecha antes de aplicar la paginación.

Las rutas de productos del vendedor devuelven únicamente recursos de su propiedad. El registro de Postor requiere aceptar la política de pujas. El historial público de pujas expone alias, monto y fecha; no datos personales.

## Reglas de negocio implementadas

- Los estados temporales de subasta son `PROGRAMADA` antes del inicio, `ACTIVA` desde el inicio y, al alcanzar el cierre, `CERRADA` si hubo pujas o `FINALIZADA_SIN_GANADOR` si no las hubo. El estado se calcula al consultar y un APScheduler ejecuta la actualización persistida cada minuto cuando `SCHEDULER_ENABLED` está habilitado.
- Las pujas solo se aceptan mientras la subasta está activa y antes de su fecha de cierre. El mínimo es el precio base si aún no hay pujas; de lo contrario, es la puja líder más el incremento mínimo. Se rechaza un monto ya registrado y el líder actual no puede pujar sobre sí mismo.
- La creación de pujas se procesa en una transacción con bloqueo de fila de la subasta (`FOR UPDATE`) para serializar pujas concurrentes.
- Al cerrar con pujas válidas, la puja más alta determina al ganador; al cerrar sin pujas el estado es `FINALIZADA_SIN_GANADOR`.
- Las respuestas públicas de subastas e historial identifican usuarios únicamente mediante alias. No exponen datos personales ni contraseñas.
- `DELETE /api/v1/products/{product_id}` elimina físicamente el producto si no tiene subastas. Si tiene una subasta `ACTIVA`, responde `409`; si tiene subastas `PROGRAMADA`, desactiva el producto y cancela esas subastas. Si solo tiene historial `CERRADA`, `FINALIZADA_SIN_GANADOR` o `CANCELADA`, desactiva el producto y conserva las subastas sin cambios. Los cambios de estado quedan registrados en `status_history`; la respuesta incluye `result` y `status`.
- El listado de subastas del vendedor está paginado y limitado a sus productos. El listado administrativo permite consultar todos los estados; la cancelación administrativa conserva las pujas y registra motivo, fecha y responsable en una transacción.

## Pruebas

Desde `backend/`, ejecuta la suite con:

```powershell
pytest -q
```

El script `backend/scripts/concurrency_test.py` envía pujas simultáneas con el mismo monto a una subasta existente. Con la API en ejecución, desde `backend/` puedes invocarlo así:

```powershell
python scripts/concurrency_test.py --url http://localhost:8000 --auction-id ID --tokens TOKEN1 TOKEN2 --n 12 --amount 100.00
```

Reemplaza `ID`, `TOKEN1`, `TOKEN2` y el monto por valores apropiados para la subasta de prueba. El script informa cuántas solicitudes fueron aceptadas, rechazadas por la API o tuvieron errores de conexión; no imprime los tokens.
