# Frontend

Aplicación Angular standalone con Angular Material. El proyecto incluye Node.js local 24.15 para ejecutar Angular CLI. Requiere npm.

```powershell
cd frontend
npm install
npm start
```

La aplicación queda disponible en `http://localhost:4200`. Para compilar producción:

```powershell
npm run build
```

Los scripts usan el Node local incluido en las dependencias del proyecto, por lo que no dependen de la versión global de Node.

La URL base de la API se configura en `src/environments/environment.ts`.

## Funciones conectadas a la API

- Catálogo y detalle públicos de subastas. El catálogo admite el filtro `status`; sin filtro la API entrega activas y programadas, y la vista agrupa disponibles y cerradas.
- Postor: `GET /me/auctions`, historial público de pujas y creación de pujas.
- Vendedor: productos propios, `GET /me/seller/auctions`, creación/edición de subastas e historial de pujas.
- Administrador: `/admin/subastas` consume `GET /admin/auctions` y `POST /admin/auctions/{id}/cancel`; `/admin/usuarios` consume `GET /admin/users` y `PATCH /admin/users/{id}/status`.

Los endpoints de administración requieren rol `ADMIN`. Los errores de la API se presentan en snackbar mediante el interceptor global.
