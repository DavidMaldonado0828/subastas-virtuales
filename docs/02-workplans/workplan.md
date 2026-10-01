# Plan de trabajo — Sistema de Subastas Virtuales

## Propósito y criterio de priorización

El SRS `docs/01-srs/negocio_y_alcance_subastas.md` es la fuente de verdad. Cada tarea tiene una prioridad según la sección MoSCoW del SRS. Cuando una tarea amplía un enunciado MoSCoW general con detalles de historias o requisitos funcionales cuya prioridad no se especifica, se marca **[SHOULD]** como asignación provisional, pendiente de validación; los casos están identificados en Observaciones. Los identificadores entre corchetes indican referencias al SRS.

## Fase 1 — Cuentas, acceso, categorías y productos

### Bloque 1.1 — Cuentas y control de acceso

- [ ] **[MUST] F1-B1-T1. Registro e inicio de sesión con roles:** permitir registro e inicio de sesión de Vendedor, Postor/Participante y Administrador, mostrando el panel correspondiente. **Verificación:** cada rol puede iniciar sesión y recibe su panel correspondiente. [MoSCoW: Must have — registro/login con roles; RF: registro e inicio de sesión]
- [ ] **[MUST] F1-B1-T2. Autenticación de acciones protegidas:** exigir autenticación para crear productos/subastas, pujar y consultar historial personal, manteniendo públicas las consultas de catálogo y detalle. **Verificación:** se permite consulta pública y se exige autenticación en las acciones protegidas indicadas. [MoSCoW: Must have — seguridad; RN: 3.6; RNF: Seguridad]
- [ ] **[MUST] F1-B1-T3. Autorización por rol y pertenencia:** validar permisos por rol en endpoints y limitar al Vendedor a sus productos y subastas. **Verificación:** se rechazan acciones de rol no autorizado y gestión de recursos de otro vendedor. [MoSCoW: Must have — seguridad; RN: 3.6; RNF: Seguridad]
- [ ] **[MUST] F1-B1-T4. Protección de contraseñas y validación de entradas:** almacenar contraseñas mediante hash seguro sin exponerlas y validar/sanear entradas de usuario. **Verificación:** ninguna respuesta expone contraseñas y las entradas inválidas se rechazan. [MoSCoW: Must have — seguridad; RNF: Seguridad]
- [ ] **[SHOULD] F1-B1-T5. Actualización y eliminación de cuenta del Participante:** permitir actualizar nombre, teléfono y email; impedir edición/desactivación con puja líder vigente en subasta activa; desactivar al eliminar si tiene historial de pujas y eliminar por completo si no lo tiene. **Verificación:** se validan los campos, las condiciones de bloqueo y ambos resultados de eliminación. [Prioridad no indicada expresamente; RF: cuenta del Participante]
- [ ] **[SHOULD] F1-B1-T6. Bloqueo y reactivación de cuentas:** permitir al Administrador cambiar el estado entre activa y bloqueada; bloquear inicio de sesión y acciones hasta reactivación y conservar el historial. **Verificación:** bloqueo, reactivación y preservación de historial se comprueban. [MoSCoW: Should have — panel básico de administrador, bloquear usuario; RF: estado de cuentas]

### Bloque 1.2 — Categorías y productos

- [x] **[MUST] F1-B2-T1. Registro de productos:** permitir al Vendedor registrar productos con nombre, descripción, categoría e imagen y rechazar registros incompletos. **Verificación:** producto completo se registra y producto incompleto se rechaza. [MoSCoW: Must have — CRUD de productos; RF: registro de productos]
- [x] **[MUST] F1-B2-T2. Consulta y filtros MVP de productos:** permitir consultar productos y filtrar por marca y categoría. **Verificación:** los filtros por marca y categoría devuelven productos coincidentes. [MoSCoW: Must have — filtros de búsqueda del producto (marca, categoría); RF: búsqueda y filtros]
- [ ] **[SHOULD] F1-B2-T3. Filtros adicionales de productos propios:** permitir al Vendedor filtrar sus productos por estado; el criterio por nombre de la historia de usuario queda pendiente de validación por la diferencia indicada en Observaciones. **Verificación:** el filtro por estado funciona para los estados descritos en el SRS. [Prioridad no indicada expresamente; HU Vendedor]
- [x] **[MUST] F1-B2-T4. Actualización de productos:** permitir editar campos del producto según las restricciones de asociación con subastas descritas en el SRS: todos los campos si nunca estuvo en subasta Activa/Cerrada (incluida solo Programada); únicamente descripción e imagen si está vinculado a Activa/Cerrada. **Verificación:** se validan los campos editables en ambos escenarios. [MoSCoW: Must have — CRUD de productos; RF: actualización de productos]
- [x] **[MUST] F1-B2-T5. Eliminación o desactivación de productos por el Vendedor:** eliminar completamente solo productos sin asociación a subastas y desactivar los asociados. **Verificación:** el resultado corresponde a la existencia o ausencia de asociación. [MoSCoW: Must have — CRUD de productos; RF: eliminación de productos]
- [ ] **[SHOULD] F1-B2-T6. Gestión de categorías:** permitir al Administrador crear categorías, editar nombre/descripción y desactivarlas; impedir asignar categorías desactivadas a productos nuevos y conservar sus referencias existentes. **Verificación:** se verifican operaciones y reglas tras la desactivación. [Prioridad no indicada expresamente; RF: categorías]
- [ ] **[SHOULD] F1-B2-T7. Suspensión administrativa de productos:** permitir suspender productos que incumplan normas, impedir su asociación con nuevas subastas y conservar su historial. **Verificación:** se verifica la restricción de asociación y la conservación del historial. [Prioridad no indicada expresamente; RF: suspensión de productos]

## Fase 2 — Creación y consulta de subastas

### Bloque 2.1 — Gestión de subastas por el Vendedor

- [ ] **[MUST] F2-B1-T1. Creación de subastas:** permitir crear una subasta a partir de un producto registrado, indicando precio base, incremento mínimo, fecha de inicio y fecha de cierre. **Verificación:** queda registrada la subasta con esos parámetros y el producto asociado. [MoSCoW: Must have — CRUD de subastas; RF: creación de subasta]
- [ ] **[MUST] F2-B1-T2. Actualización de subastas sin pujas:** permitir al Vendedor modificar precio base, incremento mínimo y fechas de inicio/cierre únicamente cuando no haya pujas registradas. **Verificación:** cambios sin pujas se aceptan y con pujas se rechazan. [MoSCoW: Must have — CRUD de subastas; RF: actualización de subastas]
- [ ] **[SHOULD] F2-B1-T3. Cancelación de subasta por el Vendedor sin pujas:** permitir cancelar una subasta propia si no tiene pujas. **Verificación:** se permite sin pujas y se rechaza con pujas. [MoSCoW: Should have — cancelar subasta sin pujas (vendedor)]
- [ ] **[SHOULD] F2-B1-T4. Filtros de subastas del Vendedor:** filtrar subastas propias por fecha de cierre, categoría y estado. **Verificación:** cada criterio devuelve únicamente subastas propias coincidentes. [Prioridad no indicada expresamente; RF: filtros de subastas]

### Bloque 2.2 — Catálogo y detalle público

- [ ] **[MUST] F2-B2-T1. Catálogo público mínimo:** permitir consultar el catálogo público de subastas. **Verificación:** un usuario puede abrir el catálogo sin autenticación. [MoSCoW: Must have — vistas mínimas: catálogo]
- [ ] **[MUST] F2-B2-T2. Detalle de subasta:** mostrar producto, precio base, incremento mínimo, puja líder actual y tiempo restante. **Verificación:** el detalle presenta esos datos para una subasta consultable. [MoSCoW: Must have — vista detalle de subasta; HU Participante]
- [ ] **[SHOULD] F2-B2-T3. Filtros del catálogo por categoría y fecha de cierre:** permitir filtrar el catálogo mediante esos criterios. **Verificación:** los resultados corresponden a la categoría y fecha seleccionadas. [Prioridad no indicada expresamente; RF: catálogo público]
- [ ] **[SHOULD] F2-B2-T4. Filtros del catálogo por estado temporal:** filtrar subastas activas, próximas y cerradas. **Verificación:** cada filtro devuelve subastas del estado/condición temporal seleccionada. [MoSCoW: Should have — filtros en el catálogo (activas/próximas/cerradas)]
- [ ] **[MUST] F2-B2-T5. Cambio automático Programada → Activa → Cerrada:** actualizar automáticamente el estado según las fechas de inicio y cierre, representando el recorrido MVP. **Verificación:** el estado cambia al inicio y al cierre conforme al calendario de la subasta. [MoSCoW: Must have — cambio de estado automático]
- [ ] **[MUST] F2-B2-T6. Consistencia de estados en vistas:** reflejar el estado real de subastas y productos de forma consistente en las vistas aplicables. **Verificación:** la misma entidad muestra el mismo estado en catálogo y paneles donde aparece. [Prioridad no indicada expresamente; RNF: Usabilidad]

## Fase 3 — Pujas, cierre e historial

### Bloque 3.1 — Registro y consulta de pujas

- [ ] **[MUST] F3-B1-T1. Aceptación de la política vinculante:** requerir al Participante aceptar al registrarse la política según la cual las pujas son vinculantes y no se retiran, para poder participar. **Verificación:** sin aceptación no puede participar. [Prioridad no indicada expresamente; HU Participante; RN: 3.2]
- [ ] **[MUST] F3-B1-T2. Validación de pujas:** aceptar pujas solo durante el estado Activa y antes de la fecha de cierre, con monto igual o superior a la puja líder más el incremento mínimo; rechazar las demás. **Verificación:** se comprueban estado, fecha e importe límite. [MoSCoW: Must have — pujar con validación de incremento mínimo; RF: pujas]
- [ ] **[MUST] F3-B1-T3. Puja líder y desempate temporal:** actualizar la puja líder con cada puja válida y rechazar una segunda puja del mismo monto cuando existe una primera registrada. **Verificación:** lidera la puja válida más alta y el mismo monto se resuelve por timestamp. [MoSCoW: Must have — pujar con validación de incremento mínimo; RN: 3.2]
- [ ] **[MUST] F3-B1-T4. Consistencia ante pujas simultáneas:** garantizar que pujas concurrentes no permitan aceptar montos iguales o inferiores al mínimo requerido. **Verificación:** las pujas aceptadas simultáneamente respetan el incremento y dejan una puja líder consistente. [Prioridad no indicada expresamente; RNF: Rendimiento y disponibilidad]
- [ ] **[COULD] F3-B1-T5. Anti-sniping:** extender el tiempo de cierre cuando ocurra una puja de último minuto, conforme al comportamiento que se defina para este mecanismo. **Verificación:** una puja en el intervalo de último minuto activa la extensión prevista. [MoSCoW: Could have — anti-sniping]
- [ ] **[COULD] F3-B1-T6. Notificaciones en tiempo real:** notificar en tiempo real los eventos pertinentes de subastas mediante WebSockets. **Verificación:** un evento de subasta se recibe en tiempo real por los clientes conectados. [MoSCoW: Could have — notificaciones en tiempo real (WebSockets)]
- [ ] **[MUST] F3-B1-T7. Consulta de mis pujas / mis subastas:** permitir al Participante consultar las subastas en las que puja o pujó. **Verificación:** la vista lista las subastas asociadas a sus pujas. [MoSCoW: Must have — vistas mínimas: mis pujas/mis subastas]
- [ ] **[SHOULD] F3-B1-T8. Filtro de subastas del Participante por estado:** filtrar su lista por activa, cerrada y cancelada. **Verificación:** cada filtro limita los resultados al estado seleccionado. [Prioridad no indicada expresamente; RF: subastas del Participante]
- [ ] **[SHOULD] F3-B1-T9. Detalle de pujas para el Vendedor:** mientras la subasta esté activa, mostrar alias de cada Participante, valor y fecha de cada puja, historial de esa subasta y puja líder actual, sin datos personales. **Verificación:** se muestran los datos requeridos y se excluyen datos personales. [Prioridad no indicada expresamente; RF/HU Vendedor]

### Bloque 3.2 — Cierre, resultados e historial

- [ ] **[MUST] F3-B2-T1. Determinación automática del ganador:** al cierre, declarar ganador al Participante con la puja válida más alta. **Verificación:** la subasta con pujas válidas termina con el participante de mayor puja como ganador. [MoSCoW: Must have — determinación automática de ganador al cierre]
- [ ] **[SHOULD] F3-B2-T2. Estado Finalizada sin ganador:** marcar expresamente así una subasta cerrada sin pujas. **Verificación:** al cierre sin pujas, el estado resultante es Finalizada sin ganador. [MoSCoW: Should have — manejo explícito de estado Finalizada sin ganador]
- [ ] **[MUST] F3-B2-T3. Historial de pujas y estados por subasta:** guardar cada puja y cambio de estado como registro individual, conservando el orden y sin sobrescribir eventos previos. **Verificación:** puede reconstruirse la secuencia de pujas y estados de una subasta. [MoSCoW: Must have — historial de pujas y estados por subasta; RN: 3.5]
- [ ] **[SHOULD] F3-B2-T4. Historial del usuario y consulta de resultados:** permitir consultar actividad del usuario y al Vendedor/Participante el resultado de sus subastas cerradas. **Verificación:** se consultan subastas creadas, pujas realizadas y resultado ganado/perdido o sin ganador aplicable. [Prioridad no indicada expresamente; RN: 3.5; HU Vendedor y Participante]
- [ ] **[COULD] F3-B2-T5. Historial visual tipo línea de tiempo con gráficos:** presentar visualmente los eventos de subasta en una línea de tiempo con gráficos. **Verificación:** el historial visual representa los eventos registrados cronológicamente. [MoSCoW: Could have — historial visual tipo línea de tiempo con gráficos]

## Fase 4 — Funciones administrativas y entrega

### Bloque 4.1 — Supervisión y acciones administrativas

- [ ] **[SHOULD] F4-B1-T1. Panel básico de administrador — bloqueo de usuario:** permitir bloquear y reactivar cuentas de usuario desde las funciones administrativas. **Verificación:** la cuenta bloqueada no puede iniciar sesión ni realizar acciones, y puede reactivarse. [MoSCoW: Should have — panel básico de administrador, bloquear usuario]
- [ ] **[SHOULD] F4-B1-T2. Panel básico de administrador — retirar/eliminar subasta:** permitir al Administrador retirar o eliminar una subasta desde sus funciones básicas; el significado de eliminar frente a cancelar queda sujeto a la observación sobre la discrepancia del SRS. **Verificación:** la subasta deja de estar disponible según la acción administrativa que se defina. [MoSCoW: Should have — panel básico de administrador, eliminar subasta]
- [ ] **[SHOULD] F4-B1-T3. Cancelación administrativa con motivo e historial:** permitir al Administrador cancelar una subasta, conservar las pujas y registrar motivo, fecha y Administrador que ejecutó la acción. **Verificación:** cancelación y datos de auditoría se reflejan en el historial. [Prioridad no indicada expresamente para este alcance detallado; RF: cancelación administrativa]
- [ ] **[SHOULD] F4-B1-T4. Consulta administrativa de subastas:** permitir al Administrador consultar todas las subastas, con producto, vendedor, precio base, incremento mínimo, fechas e historial de pujas. **Verificación:** la consulta incluye las subastas de todos los estados y los datos enumerados. [Prioridad no indicada expresamente; RF: listado administrativo]
- [ ] **[SHOULD] F4-B1-T5. Información del vendedor:** mostrar al Participante información del vendedor sin exponer sus datos personales. **Verificación:** se presenta información del vendedor y se excluyen sus datos personales. [Prioridad no indicada expresamente; HU Participante]
- [ ] **[COULD] F4-B1-T6. Dashboard / estadísticas del Administrador:** mostrar indicadores generales de subastas, usuarios y productos por categoría. **Verificación:** se presentan los indicadores definidos en el requerimiento funcional. [MoSCoW: Could have — dashboard/estadísticas para el administrador; RF: panel de indicadores]

### Bloque 4.2 — Coherencia y requisitos transversales

- [ ] **[SHOULD] F4-B2-T1. Mensajes de error claros:** presentar mensajes específicos cuando una acción se rechaza, por ejemplo por puja insuficiente, falta de permisos o subasta cerrada. **Verificación:** cada rechazo comunica claramente su causa. [Prioridad no indicada expresamente; RNF: Usabilidad]
- [ ] **[MUST] F4-B2-T2. Validación de montos y fechas en servidor:** validar en servidor montos de puja y fechas de subasta antes de persistirlos, sin confiar en valores manipulables del cliente. **Verificación:** valores fuera de regla se rechazan antes de guardarse. [MoSCoW: Must have — seguridad; RNF: Seguridad]
- [ ] **[SHOULD] F4-B2-T3. Rendimiento de consultas y concurrencia:** verificar respuesta aceptable de catálogo y detalle con múltiples pujas concurrentes y consistencia de datos ante pujas simultáneas. **Verificación:** consultas y resultados concurrentes cumplen los criterios descritos en el SRS; el umbral de respuesta requiere definición. [Prioridad no indicada expresamente; RNF: Rendimiento y disponibilidad]

## Funcionalidades Won't have — fuera del alcance

Los siguientes elementos se identifican como excluidos por el SRS y **no se planifican para implementación**:

- Pagos reales o pasarela de pago.
- Chat entre Vendedor y Postor.
- Aplicación móvil nativa.
- Soporte multi-idioma.

## Observaciones

1. **Prioridad provisional de requisitos detallados:** el SRS MoSCoW prioriza funcionalidades generales, pero no asigna prioridad a todos los detalles de historias y requerimientos funcionales. Las tareas marcadas **[SHOULD]** con la nota «Prioridad no indicada expresamente» son una ubicación provisional para mantener trazabilidad, no una prioridad declarada por el SRS. Deben validarse antes de usarse para comprometer alcance.
2. **Marca de producto:** MoSCoW incluye filtros de producto por marca y categoría, mientras que las historias/requisitos funcionales y el modelo de producto no describen el campo marca. Se planificó el filtro por categoría; el filtro por marca queda sin tarea hasta aclarar si marca forma parte del producto.
3. **Cancelar/eliminar subasta por Administrador:** MoSCoW menciona «eliminar subasta» en el panel básico; el requerimiento funcional especifica cancelar subastas con o sin pujas y registrar motivo, fecha y Administrador. No queda definido si «eliminar» significa cancelar/retirar de catálogo o borrado definitivo; no se interpreta como borrado definitivo en este plan.
4. **Estados automáticos:** MoSCoW enumera Programada → Activa → Cerrada como recorrido Must have, mientras el SRS distingue Cerrada/Finalizada con ganador y Finalizada sin ganador. Se prioriza el recorrido explícito Must; el estado explícito Finalizada sin ganador queda Should conforme a MoSCoW.
5. **Cancelación de subasta:** la sección de roles y la regla 3.3 limitan al Vendedor a cancelación sin pujas y requieren Administrador si ya hay pujas; el requerimiento funcional permite al Administrador cancelar cualquier subasta, tenga o no pujas. La prioridad del panel básico y la prioridad del alcance administrativo detallado no coinciden de manera inequívoca.
6. **Edición de subastas:** la historia y requerimiento funcional permiten actualizar parámetros solo si no hay pujas, mientras la regla 3.3 permite editar descripción e imágenes durante la actividad y restringe ciertos parámetros tras pujas. El SRS no aclara cómo se concilian estos casos.
7. **Estados de productos:** se usan «desactivado», «desactivado por incumplimiento» y «eliminado por incumplimiento», sin definir si las dos últimas expresiones representan el mismo estado.
8. **Requisitos MoSCoW Could:** anti-sniping, notificaciones en tiempo real, dashboard/estadísticas e historial visual se mantienen como tareas [COULD] explícitas. No se incorporan otras funcionalidades «Won't have» al plan de implementación.

## Requisitos sin asignación clara o pendiente de definición

- **Filtro por marca:** figura en Must have y está cubierto por F1-B2-T2. Sin embargo, el SRS no define el campo marca en historias, requerimientos funcionales ni modelo del producto; debe aclararse su representación para ejecutar y verificar el filtro.
- **Filtro de productos propios por nombre:** aparece en la historia del Vendedor; el requerimiento funcional solo menciona categoría y estado. Queda fuera de las tareas hasta resolver la diferencia.
- **Búsqueda de productos:** el requerimiento funcional dice buscar y filtrar por categoría y estado, pero no concreta criterio ni comportamiento de búsqueda.
- **Resolver reclamos:** se menciona como ejemplo de acción administrativa, sin historia o requerimiento que defina el flujo.
- **Aceptación de política de pujas:** se incluye en una historia, pero no hay requisito funcional sobre almacenamiento/consulta de la aceptación.
- **Información pública del vendedor:** la historia la solicita sin definir qué campos son públicos.
- **Diseño técnico por separado:** ERD, endpoints, mockups y arquitectura de seguridad se documentan aparte, pero no se definen entregables/criterios concretos para incorporarlos como tareas aquí.
- **Criterios medibles de rendimiento:** el SRS exige un tiempo «aceptable», sin umbral ni carga de referencia.
- **Filtros del catálogo por categoría/fecha y de subastas propias por fecha/categoría/estado:** están en requerimientos/historias, pero no aparecen expresamente en la lista MoSCoW; están provisionalmente [SHOULD].

## Matriz breve de trazabilidad por prioridad

| Prioridad MoSCoW del SRS | Requisito / funcionalidad | Tareas relacionadas |
|---|---|---|
| **MUST** | Registro/login con roles | F1-B1-T1 |
| **MUST** | CRUD de productos | F1-B2-T1, F1-B2-T4, F1-B2-T5 |
| **MUST** | Filtros de producto por marca y categoría | F1-B2-T2 |
| **MUST** | CRUD de subastas: parámetros y fechas | F2-B1-T1, F2-B1-T2 |
| **MUST** | Cambio automático Programada → Activa → Cerrada | F2-B2-T5 |
| **MUST** | Pujar con validación de incremento mínimo | F3-B1-T2, F3-B1-T3 |
| **MUST** | Determinación automática de ganador al cierre | F3-B2-T1 |
| **MUST** | Historial de pujas y estados por subasta | F3-B2-T3 |
| **MUST** | Autenticación y autorización por rol | F1-B1-T2, F1-B1-T3, F1-B1-T4, F4-B2-T2 |
| **MUST** | Vistas mínimas: catálogo, detalle, mis pujas/mis subastas | F2-B2-T1, F2-B2-T2, F3-B1-T7 |
| **SHOULD** | Cancelar subasta sin pujas por Vendedor | F2-B1-T3 |
| **SHOULD** | Panel básico: bloquear usuario y eliminar subasta | F1-B1-T6, F4-B1-T1, F4-B1-T2 |
| **SHOULD** | Estado Finalizada sin ganador | F3-B2-T2 |
| **SHOULD** | Filtros del catálogo: activas/próximas/cerradas | F2-B2-T4 |
| **COULD** | Anti-sniping | F3-B1-T5 |
| **COULD** | Notificaciones en tiempo real (WebSockets) | F3-B1-T6 |
| **COULD** | Dashboard/estadísticas del Administrador | F4-B1-T6 |
| **COULD** | Línea de tiempo con gráficos | F3-B2-T5 |
| **Won't have** | Pagos, chat, aplicación móvil nativa, multi-idioma | Fuera del alcance; ninguna tarea de implementación |

### Cobertura de Must have

Todas las funcionalidades Must have explícitas tienen al menos una tarea [MUST] asociada: registro/roles, CRUD de productos y subastas, filtros por marca y categoría, cambios automáticos de estado, pujas con incremento mínimo, determinación automática del ganador, historial de pujas/estados, seguridad y vistas mínimas. La falta de definición del campo marca se registra como observación para resolver antes de implementar y verificar ese filtro.
