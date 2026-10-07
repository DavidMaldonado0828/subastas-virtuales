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
