# Sistema de Subastas Virtuales

Aplicación web para publicar productos en subasta, participar con pujas y administrar usuarios y subastas. Tiene tres roles: **Vendedor**, **Postor** y **Administrador**.

## Arquitectura

```text
Angular + Angular Material  →  FastAPI  →  PostgreSQL en Neon
```

El frontend Angular consume la API REST de FastAPI. El backend organiza el acceso mediante routers, servicios y repositorios/modelos; PostgreSQL en Neon almacena usuarios, productos, subastas, pujas e historial.

## Requisitos

- Windows 10/11 y PowerShell.
- Python 3.10 o superior y `pip`.
- Node.js 24.x y npm 11.x.
- Cuenta y proyecto PostgreSQL en Neon.

## Base de datos — Neon

Crea un proyecto en Neon y configura localmente estas variables en `backend/.env`. `DATABASE_URL` usa la conexión directa para Alembic y `DATABASE_URL_POOLED` usa la conexión agrupada para la aplicación. Obtén ambos valores directamente desde Neon; no los guardes en Git ni los compartas.

| Variable | Uso |
| --- | --- |
| `DATABASE_URL` | Conexión directa para migraciones Alembic. |
| `DATABASE_URL_POOLED` | Conexión de la aplicación FastAPI. |

No se muestran valores de conexión en esta documentación.

## Levantar los servicios en Windows

### 1. Backend

Abre una terminal PowerShell desde la raíz del repositorio y ejecuta:

```powershell
cd backend
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
alembic upgrade head
python -m scripts.seed_users
uvicorn app.main:app --reload
```

El seed crea el administrador inicial y categorías de ejemplo. La API y Swagger quedan disponibles en el puerto `8000`.

### 2. Frontend

En otra terminal PowerShell, desde la raíz del repositorio:

```powershell
cd frontend
npm install
npm start
```

Abre [http://localhost:4200](http://localhost:4200).

## Usuarios de prueba

El seed incluye solo esta cuenta. Su contraseña se configura localmente mediante `SEED_ADMIN_PASSWORD`; no se incluye aquí.

| Alias | Rol |
| --- | --- |
| `admin_subastas` | ADMIN |

El seed no crea cuentas de VENDEDOR ni POSTOR. Regístralas desde la aplicación para probar esos roles; el registro de POSTOR requiere aceptar la política vinculante de pujas.

Para cargar el conjunto de productos y subastas de demostración cuando existan los alias requeridos:

```powershell
cd backend
python -m scripts.seed_demo
```

Para restablecer solo los datos atribuibles a ese script, ejecuta `python -m scripts.seed_demo --reset` desde `backend/` y confirma escribiendo `BORRAR DEMO`. El seed no crea cuentas de VENDEDOR ni POSTOR.

## Pruebas

Desde la raíz del repositorio, abre PowerShell:

```powershell
cd backend
pytest -q
```

Para probar pujas simultáneas, inicia primero el backend y prepara una subasta ACTIVA y tokens válidos de dos POSTORES. Desde una segunda terminal:

```powershell
cd backend
python scripts/concurrency_test.py --url http://localhost:8000 --auction-id <ID_SUBASTA> --tokens <TOKEN_POSTOR_1> <TOKEN_POSTOR_2> --n 12 --amount 100.00
```

El script intenta pujas concurrentes por el mismo monto y resume las respuestas. Sustituye los marcadores por datos de tu entorno local.

## Decisiones de implementación que difieren del SRS

- `image_url` es opcional y nullable para permitir productos sin imagen.
- Los montos se almacenan como `Numeric(12,2)`, adecuado para importes en COP; el ERD del SRS indicaba `Numeric(15,5)`.

## Documentación relacionada

- [README del backend](backend/README.md)
- [README del frontend](frontend/README.md)
- [Documentación del proyecto](docs/)
- [Repositorio en GitHub](https://github.com/DavidMaldonado0828/subastas-virtuales)
