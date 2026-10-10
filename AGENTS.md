# Sistema de Subastas Virtuales

## Fuente de verdad y plan

- Fuente de verdad funcional:
  `docs/01-srs/negocio_y_alcance_subastas.md`
- Plan de trabajo:
  documento ubicado en `docs/02-workplans/`, con IDs de tareas tipo
  `MUST`.
- No inventar requisitos.
- No resolver contradicciones del SRS silenciosamente.
- Si existe una ambigüedad que no esté resuelta en este archivo,
  preguntar antes de asumir.

## Stack obligatorio

- Backend: FastAPI + Pydantic v2 + SQLAlchemy 2.0 + Alembic, en `/backend`.
- Base de datos: PostgreSQL en Neon.
- `DATABASE_URL` debe estar en `.env` y nunca en el repositorio.
- Incluir `.env.example` sin credenciales reales.
- Auth: JWT + hash Argon2 o bcrypt.
- Roles:
  - `VENDEDOR`
  - `POSTOR` (Participante en el SRS)
  - `ADMIN`
- Estados automáticos:
  - APScheduler cada minuto.
  - Además, calcular el estado según fechas al consultar para evitar
    depender exclusivamente del scheduler.
- Tests: pytest + httpx.
- Frontend: Angular con standalone components + Angular Material,
  en `/frontend`.

## Alcance

- MVP = únicamente tareas `[MUST]`.
- No implementar tareas `[SHOULD]` salvo que el usuario lo indique
  explícitamente.
- No implementar tareas `[COULD]`.
- No implementar funcionalidades clasificadas como `Won't have`.

## Decisiones ya tomadas

### Productos

- El producto tiene un campo opcional `marca` de tipo texto.
- Los filtros de productos incluyen:
  - marca
  - categoría
  - nombre

### Subastas

- "Eliminar subasta" por parte del Administrador significa cancelar
  la subasta con:
  - motivo
  - fecha
  - administrador responsable
- Nunca realizar borrado físico de una subasta.

### Pujas

- Las pujas se validan siempre en el servidor.
- La creación de una puja debe ejecutarse dentro de una transacción.
- Utilizar bloqueo de fila de la subasta para controlar concurrencia.
- El monto mínimo aceptado es:
  - puja líder + incremento mínimo, si ya existen pujas;
  - precio base, si todavía no existen pujas.
- Una puja con el mismo monto que una puja existente se rechaza.
- En caso de montos iguales, la primera puja registrada es la válida.

### Estados

Flujo:

`PROGRAMADA -> ACTIVA -> CERRADA`

Al finalizar una subasta:

- Si existen pujas válidas: determinar ganador.
- Si no existen pujas: resultado `FINALIZADA_SIN_GANADOR`.

### Privacidad

- Nunca exponer contraseñas.
- Nunca exponer datos personales de vendedores o postores en
  información pública de subastas o pujas.
- Utilizar `alias` para identificar públicamente a los usuarios.

### Historial

- Las pujas y cambios de estado se almacenan como registros
  individuales.
- Nunca sobrescribir registros históricos.
- Nunca eliminar registros históricos como parte de una actualización
  normal.

## Reglas de trabajo

1. Trabajar una fase y un bloque a la vez, siguiendo el orden del plan.
2. Backend primero y frontend después dentro de cada fase.
3. Mantener separación de capas:

   `routers (HTTP) -> services (lógica) -> repositories/models (datos)`

4. No colocar lógica de negocio en los routers.
5. Validar montos y fechas siempre en el servidor.
6. Al terminar cada bloque:
   - ejecutar los tests;
   - listar los IDs de tareas completadas;
   - indicar cómo verificar manualmente cada tarea.
7. Marcar `[x]` en el plan únicamente después de verificar la tarea.
8. Realizar commits usando CONVENTIONAL COMMITS pequeños por bloque y antes de hacerlo avisarme.
9. No refactorizar código que no sea necesario para la tarea actual.
10. No modificar decisiones ya tomadas sin autorización.
11. Si algo es ambiguo y no está definido en este archivo ni en el SRS,
    preguntar antes de asumir.

## Regla para contradicciones

- El SRS es la fuente de verdad para requisitos y alcance.
- Las decisiones explícitas de este archivo representan decisiones
  técnicas/de implementación ya tomadas.
- Si este archivo contradice explícitamente un requisito del SRS,
  detenerse y señalar la contradicción.
- No elegir silenciosamente una interpretación.
- No implementar una funcionalidad adicional "por si acaso".

## Antes de modificar código

Antes de comenzar una tarea:

1. Identificar el ID de la tarea del workplan.
2. Leer el requisito correspondiente del SRS.
3. Comprobar las decisiones de este archivo.
4. Indicar brevemente qué se va a implementar.
5. Implementar únicamente el alcance de esa tarea.

Cambio adicional:

- image_url es opcional (nullable). Decisión consciente por resiliencia de la
demo; difiere del SRS, que la lista como parte del producto."
Si la migración inicial ya se generó, ajústala para que la columna sea nullable.
- Montos Numeric(12,2); difiere del ERD del SRS (15,5) por ser dinero en COP.
