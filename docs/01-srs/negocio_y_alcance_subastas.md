# Sistema de Subastas Virtuales

## Documento de Negocio — Reglas y Alcance del Proyecto

Proyecto: Sistema de Subastas Virtuales (individual)

Periodo de entrega: 12/09/2026 – 05/10/2026

Fecha del documento: 13/09/2026

1. Descripción General del Negocio

El sistema permite a un vendedor publicar productos en subasta y a distintos participantes competir por ellos mediante pujas, hasta que el sistema determina automáticamente un ganador al cierre de cada subasta. Todo el proceso queda registrado para consulta posterior.

Flujo principal del negocio:

El Vendedor registra un producto y define los parámetros de la subasta (precio base, incremento mínimo, fecha de inicio y fecha de cierre).

La subasta se publica en el catálogo y los Participantes (Postores) pueden consultarla.

Durante el periodo activo, los Postores realizan pujas; cada puja válida se convierte en la puja líder.

Al llegar la fecha/hora de cierre, el sistema cambia el estado de la subasta y determina el ganador de forma automática.

Cada evento (puja, cambio de estado, resultado final) queda almacenado en el historial de la subasta y del usuario.

2. Roles del Sistema

Administrador

Supervisa el sistema de forma integral. Ejemplos de acciones:

Bloquear o activar cuentas de usuarios (ej. un postor con actividad fraudulenta).

Eliminar o suspender un producto/subasta que incumpla normas.

Cancelar una subasta activa en caso de disputa o error grave del vendedor.

Consultar un panel global con todas las subastas y su historial.

Resolver reclamos entre vendedor y postor.

Vendedor / Publicador

Gestiona únicamente sus propios productos y subastas: creación, consulta de estado, y cancelación solo si la subasta aún no tiene pujas.

Postor / Participante

Consulta el catálogo público, participa pujando en subastas activas, y revisa su propio historial de pujas y resultados (ganadas/perdidas).

3. Reglas de Negocio Clave

### 3.1 Estados de una subasta

Programada: creada, aún no llega la fecha de inicio.

Activa: dentro del rango de fecha de inicio y cierre; acepta pujas.

Cerrada / Finalizada con ganador: se cumplió la fecha de cierre y hubo al menos una puja válida.

Finalizada sin ganador: se cumplió la fecha de cierre y no se registró ninguna puja.

Cancelada: el vendedor o el administrador la canceló antes del cierre (solo permitido si aún no tiene pujas o por el admin).

### 3.2 Pujas

Toda puja debe ser igual o mayor a la puja líder actual más el incremento mínimo definido (ej. líder $100.000 + incremento $5.000 → próxima puja válida ≥ $105.000).

Una puja que no cumple el incremento mínimo es rechazada automáticamente por el sistema.

Las pujas son vinculantes: no se permite retirar una puja ya realizada, para preservar la integridad de la subasta.

En caso de dos pujas por el mismo monto, se considera válida la primera registrada según marca de tiempo (timestamp); la segunda se rechaza por no superar el mínimo.

Solo se aceptan pujas mientras la subasta está en estado Activa.

### 3.3 Modificación de una subasta activa

No se permite modificar precio base, incremento mínimo ni fecha de cierre una vez que la subasta tiene pujas registradas.

Se permite editar información complementaria (descripción, imágenes) mientras la subasta está activa.

Cancelar una subasta activa solo es posible si aún no tiene pujas; si ya tiene pujas, la cancelación requiere intervención del Administrador.

### 3.4 Determinación del ganador

Al llegar la fecha/hora de cierre, el sistema evalúa automáticamente la puja líder vigente.

El participante con la puja más alta válida se declara ganador.

Si no hubo pujas, la subasta se marca como Finalizada sin ganador.

### 3.5 Historial

Cada puja, cada cambio de estado y el resultado final de la subasta quedan almacenados como registros individuales.

El historial permite reconstruir la línea de tiempo completa de una subasta y consultar la actividad de un usuario (subastas creadas, pujas realizadas, subastas ganadas).

### 3.6 Seguridad y control de acceso

Autenticación obligatoria para crear productos/subastas, pujar y consultar historial personal.

Autorización por rol en cada endpoint: un Postor no puede acceder a funciones de Vendedor o Administrador, y un Vendedor no puede gestionar subastas de otros vendedores.

Validación de todas las entradas del usuario para prevenir datos inconsistentes o manipulación de montos.

4. Alcance del Proyecto (MoSCoW)

El alcance se define bajo el método MoSCoW para priorizar frente al tiempo disponible. El criterio de corte, si el tiempo se reduce, es siempre el mismo: primero se recorta "Could have", luego "Should have"; el "Must have" no es negociable porque es lo que hace demostrable el proyecto.

### Must have — Alcance mínimo viable (MVP)

Registro / login con roles (Vendedor, Postor, Administrador)
CRUD de productos y subastas (precio base, incremento mínimo, fecha inicio/fin)
Filtros de búsqueda del producto (marca,categoría)
Cambio de estado automático (Programada → Activa → Cerrada)
Pujar con validación de incremento mínimo
Determinación automática de ganador al cierre
Historial de pujas y de estados por subasta
Seguridad: autenticación y autorización por rol en endpoints
Vistas mínimas: catálogo, detalle de subasta, mis pujas / mis subastas


### Should have — Si el tiempo alcanza
Cancelar subasta sin pujas (vendedor)
Panel básico de administrador (bloquear usuario, eliminar subasta)
Manejo explícito de estado "Finalizada sin ganador"
Filtros en el catálogo (activas / próximas / cerradas)


### Could have — Solo si sobra tiempo
Anti-sniping (extender tiempo si hay puja de último minuto)
Notificaciones en tiempo real (websockets)
Dashboard / estadísticas para el administrador
Historial visual tipo línea de tiempo con gráficos


### Won't have — Fuera de este proyecto
Pagos reales / pasarela de pago
Chat entre vendedor y postor
Aplicación móvil nativa
Soporte multi-idioma



Nota: este documento cubre el negocio y el alcance. El detalle técnico (ERD, diagrama de endpoints, mockups y arquitectura de seguridad) se documenta por separado conforme avanza el diseño en Semana 1–2 del cronograma.

5. Historias de usuarios

### Como Vendedor / Publicador

- Quiero poder registrar mis productos para poder subastarlos, indicando nombre del producto, descripción, categoría a la que pertenece e imagen.

- Quiero actualizar mi producto (nombre, descripción, imagen, categoría) siempre que nunca haya sido publicado en una subasta o esté vinculado solo a una subasta programada sin pujas. Si el producto ya participó en una subasta activa o cerrada, solo puedo editar descripción e imagen, para no alterar el historial. Si intento eliminarlo: si nunca ha sido subastado, se elimina por completo. Si tiene alguna asociación con subastas (programada, activa o cerrada), no se elimina — pasa a estado "desactivado".

- Quiero poder visualizar y filtrar mis productos por nombre, categoría y estado (activo/desactivado/subastado).

- Quiero poder crear una subasta a partir de un producto ya registrado, indicando precio base, incremento mínimo de puja, fecha de inicio y fecha de cierre.

- Quiero poder ver el detalle de las pujas hechas en mi producto mientras la subasta está activa: participante, valor de cada puja, fecha de cada puja y puja líder actual.

- Quiero poder filtrar mis subastas por fecha de cierre, categoría y estado de la subasta.

- Quiero poder actualizar o cancelar una subasta siempre y cuando no tenga pujas aún, pudiendo modificar precio base, incremento mínimo, fecha de inicio y fecha de cierre.

- Quiero poder ver, dentro de una subasta, el alias del participante y su historial de pujas en esa subasta, sin acceder a sus datos personales.

- Quiero poder ver el ganador (o si quedó sin ganador) de mis subastas cerradas, para conocer el resultado de mi venta.

### Como Participante / Postor

- Al registrarme en el sistema debo aceptar la política de pujas (las pujas son vinculantes y no pueden retirarse) para poder participar en cualquier subasta.

- Quiero poder ver y filtrar el catálogo público de subastas por categoría, estado y fecha de cierre, para decidir en cuáles participar.

- Quiero poder ver el detalle completo de una subasta (producto, precio base, incremento mínimo, puja líder actual, tiempo restante) antes de pujar, para decidir si quiero participar.

- Quiero poder pujar en una subasta activa, superando la puja líder actual en al menos el incremento mínimo, siempre que no haya pasado la fecha de cierre.

- Quiero poder visualizar todas las subastas en las que estoy o estuve pujando, filtrando por estado (activa, cerrada, cancelada).

- Quiero poder actualizar mis datos personales (nombre,teléfono,email). Si intento eliminar mi cuenta y tengo historial de pujas, en lugar de borrarse pasa a estado "desactivada"; si nunca he pujado, sí se puede eliminar por completo. No puedo editar ni desactivar mi cuenta mientras tenga una puja líder vigente en una subasta que sigue activa.

- Quiero poder ver la información del vendedor de una subasta sin acceder a sus datos personales.

- Quiero poder ver si gané o perdí una subasta cerrada en la que participé, para conocer el resultado.

### Como Administrador

- Quiero poder visualizar todas las subastas del sistema, con su detalle e historial completo.

- Quiero poder cambiar el estado de la cuenta de un usuario (activa / bloqueada) para gestionar cuentas con actividad indebida.

- Quiero poder suspender o retirar del catálogo un producto que no cumpla las normas, quedando marcado como "eliminado por incumplimiento" en lugar de borrarse, para preservar el historial de quienes ya participaron.

- Quiero poder cancelar una subasta que ya tiene pujas, en caso de disputa o incumplimiento grave, dejando constancia en el historial del motivo de la cancelación.

- Quiero poder crear, editar y desactivar las categorías de productos disponibles en el sistema, para mantener el catálogo organizado.

6. Requerimientos

### REQUERIMIENTOS FUNCIONALES:

El sistema permitirá a los usuarios registrarse e iniciar sesión, mostrando el panel correspondiente según su rol (Vendedor, Participante o Administrador).

El sistema permitirá al vendedor registrar productos indicando nombre, descripción, categoría e imagen, validando que la información sea completa antes de guardarlos.

El sistema permitirá buscar y filtrar productos por categoría y estado (Activo, Desactivado, Subastado).

El sistema permitirá al vendedor actualizar un producto: si el producto está vinculado a una subasta Activa o Cerrada, solo podrá editar la descripción y la imagen, para no alterar el historial; si el producto nunca ha participado en una subasta Activa o Cerrada (incluyendo los que solo están en una subasta Programada), podrá editar todos sus campos libremente.

El sistema permitirá al vendedor eliminar un producto únicamente si no está vinculado a ninguna subasta (ni Programada, ni Activa, ni Cerrada); en cualquier otro caso, el producto pasará a estado "desactivado" en lugar de eliminarse, para preservar la integridad del historial.

El sistema permitirá al vendedor crear una subasta a partir de un producto ya registrado, indicando precio base, incremento mínimo de puja, fecha de inicio y fecha de cierre.

El sistema permitirá al vendedor visualizar, mientras su subasta está activa, el alias de cada participante junto con su historial de pujas en esa subasta, el valor y fecha de cada puja, y la puja líder actual; al cerrarse la subasta, podrá ver el ganador. Adicionalmente, podrá filtrar sus subastas por fecha de cierre, categoría y estado.

El sistema permitirá al participante visualizar las subastas en las que está o estuvo pujando, filtrando por estado (activa, cerrada, cancelada).

El sistema permitirá al vendedor actualizar o cancelar una subasta únicamente si aún no tiene pujas registradas, pudiendo modificar precio base, incremento mínimo, fecha de inicio y fecha de cierre.

El sistema permitirá a cualquier usuario buscar y filtrar el catálogo público de subastas por categoría, estado y fecha de cierre, mostrando el detalle completo de cada una (producto, precio base, incremento mínimo, puja líder actual y tiempo restante).

El sistema permitirá al participante pujar en una subasta activa, siempre que su puja supere la puja líder actual en al menos el incremento mínimo definido y no se haya alcanzado la fecha de cierre.

El sistema permitirá al participante actualizar sus datos personales (nombre, teléfono, email) en cualquier momento. Al intentar eliminar su cuenta: si tiene historial de pujas, pasará a estado "desactivada" en lugar de eliminarse; si nunca ha pujado, se eliminará por completo. No podrá editar ni desactivar su cuenta mientras tenga una puja líder vigente en una subasta que sigue activa.

El sistema permitirá al administrador visualizar el listado completo de todas las subastas registradas, independientemente de su estado (Programada, Activa, Cerrada, Cancelada), junto con su detalle completo: producto asociado, vendedor, precio base, incremento mínimo, fechas de inicio y cierre, y el historial completo de pujas realizadas.

El sistema permitirá al administrador cambiar el estado de la cuenta de cualquier usuario entre "activa" y "bloqueada". Al bloquear una cuenta, el usuario no podrá iniciar sesión ni realizar ninguna acción (pujar, crear productos, crear subastas) hasta que su cuenta sea reactivada, pero su historial de pujas y subastas previas permanecerá visible e inalterado.

El sistema permitirá al administrador cancelar cualquier subasta, tenga o no pujas registradas, indicando un motivo obligatorio de cancelación (texto libre o de una lista predefinida: incumplimiento de normas, producto no permitido, disputa entre usuario, u otro). Al cancelarse, la subasta cambiará su estado a "Cancelada" y quedará registrado en el historial el motivo, la fecha y el administrador que ejecutó la acción, sin eliminar ninguna puja previamente realizada.

El sistema permitirá al administrador suspender un producto que no cumpla las normas del sistema, cambiando su estado a "desactivado por incumplimiento". Un producto suspendido no podrá ser vinculado a nuevas subastas, pero conservará su historial si ya participó en alguna.

El sistema permitirá al administrador crear, editar el nombre/descripción y desactivar categorías de productos. Una categoría desactivada no podrá ser asignada a nuevos productos, pero los productos que ya la tengan asignada conservarán la referencia para no romper el historial ni los filtros existentes.

El sistema permitirá al administrador consultar un panel con indicadores generales del sistema: número de subastas activas, cerradas y canceladas; número de usuarios registrados y bloqueados; y número de productos por categoría.

### REQUERIMIENTOS NO FUNCIONALES:

#### Seguridad

El sistema deberá autenticar a los usuarios mediante un mecanismo de token (ej. JWT), requerido para acceder a cualquier funcionalidad que no sea pública (consulta del catálogo y detalle de subastas).

El sistema deberá validar, en cada solicitud a un endpoint protegido, que el rol del usuario autenticado tenga autorización para ejecutar esa acción (ej. un participante no podrá acceder a endpoints exclusivos de vendedor o administrador; un vendedor no podrá modificar productos o subastas que no le pertenezcan).

El sistema deberá almacenar las contraseñas de forma cifrada (hash con algoritmo seguro, ej. bcrypt), sin exponerlas en ningún endpoint ni respuesta de la API.

El sistema deberá validar y sanear todas las entradas de datos proporcionadas por el usuario (formularios y parámetros de la API), para prevenir inyección de datos maliciosos y garantizar la integridad de la información almacenada.

El sistema deberá impedir la manipulación de montos de puja o fechas de subasta directamente desde el cliente, validando siempre estos valores en el servidor antes de persistirlos.

#### Rendimiento y disponibilidad

El sistema deberá responder a las operaciones de consulta (catálogo, detalle de subasta) en un tiempo aceptable para el usuario, incluso con múltiples pujas concurrentes sobre una misma subasta.

El sistema deberá garantizar consistencia de datos ante pujas simultáneas sobre la misma subasta, evitando que dos pujas del mismo monto o inferiores al mínimo requerido sean aceptadas al mismo tiempo (control de concurrencia a nivel de base de datos o de transacción).

#### Usabilidad

El sistema deberá presentar mensajes de error claros y específicos al usuario cuando una acción sea rechazada (ej. "la puja debe superar $X", "no tiene permisos para esta acción", "la subasta ya fue cerrada").

El sistema deberá reflejar el estado real de cada subasta y producto de forma consistente en todas las vistas donde se muestren (catálogo, panel del vendedor, panel del participante y panel del administrador).

#### Mantenibilidad y trazabilidad

El sistema deberá registrar en el historial cualquier cambio de estado relevante (de subasta, producto o cuenta de usuario) junto con la fecha/hora en que ocurrió, sin sobrescribir ni eliminar registros anteriores.

5. Stack Tecnológico

Backend:     FastAPI (Python)

Frontend:    Angular

Base de datos: PostgreSQL, Cloudinary

Auth:        JWT (con FastAPI, librería tipo python-jose o fastapi-users)

Despliegue:  Neon (backend + BD) + Vercel (frontend)

Docs API:    Swagger/OpenAPI (automático con FastAPI)

## Estructura de carpetas

/backend

/app

/models      → SQLAlchemy (User, Product, Category, Auction, Bid, StateHistory)

/schemas     → Pydantic (validación de entrada/salida)

/routers     → un archivo por entidad (users, products, categories, auctions, bids)

/core        → config, seguridad (JWT), conexión BD

main.py

requirements.txt

alembic/        → migraciones




/frontend

/src

/pages       → Login, Catalog, AuctionDetail, SellerDashboard, BidderDashboard, AdminPanel

/components  → AuctionCard, ProductCard, BidTable, StatusBadge

/services    → llamadas a la API (axios)

/context     → auth (JWT guardado, usuario actual)



## 6. MODELO RELACIONAL


erDiagram

STATUSES ||--o{ STATUS_APPLICABILITY : "applies to"

STATUSES ||--o{ USERS : "defines status"

STATUSES ||--o{ CATEGORIES : "defines status"

STATUSES ||--o{ PRODUCTS : "defines status"

STATUSES ||--o{ AUCTIONS : "defines status"

USERS ||--o{ PRODUCTS : "publishes"

CATEGORIES ||--o{ PRODUCTS : "classifies"

PRODUCTS ||--o{ AUCTIONS : "is auctioned in"

AUCTIONS ||--o{ BIDS : "receives"

USERS ||--o{ BIDS : "places"

AUCTIONS ||--o| AUCTION_CANCELLATIONS : "may have"

USERS ||--o{ AUCTION_CANCELLATIONS : "cancels as admin"

STATUSES {

int status_id PK "NOT NULL, GENERATED BY DEFAULT AS IDENTITY"

varchar(40) code UK "NOT NULL"

varchar(60) name "NOT NULL"

varchar(200) description "NULL"

boolean enabled "NOT NULL, DEFAULT TRUE"

timestamp created_at "NOT NULL, DEFAULT CURRENT_TIMESTAMP"

timestamp updated_at "NULL"

}

STATUS_APPLICABILITY {

int status_id PK,FK "NOT NULL, REFERENCES statuses.status_id"

varchar(20) entity_type PK "NOT NULL: USER, CATEGORY, PRODUCT, AUCTION"

}

USERS {

int user_id PK "NOT NULL, GENERATED BY DEFAULT AS IDENTITY"

int status_id FK "NOT NULL, REFERENCES statuses.status_id"

enum role "NOT NULL: VENDEDOR, PARTICIPANTE, ADMINISTRADOR"

varchar(100) name "NOT NULL"

varchar(50) alias UK "NOT NULL"

varchar(150) email UK "NOT NULL"

varchar(255) password_hash "NOT NULL"

varchar(200) address "NULL"

varchar(20) phone_number "NOT NULL"

timestamp created_at "NOT NULL, DEFAULT CURRENT_TIMESTAMP"

timestamp updated_at "NULL"

}

CATEGORIES {

int category_id PK "NOT NULL, GENERATED BY DEFAULT AS IDENTITY"

int status_id FK "NOT NULL, REFERENCES statuses.status_id"

varchar(100) name UK "NOT NULL"

varchar(400) description "NOT NULL"

timestamp created_at "NOT NULL, DEFAULT CURRENT_TIMESTAMP"

timestamp updated_at "NULL"

}

PRODUCTS {

int product_id PK "NOT NULL, GENERATED BY DEFAULT AS IDENTITY"

int seller_id FK "NOT NULL, REFERENCES users.user_id"

int category_id FK "NOT NULL, REFERENCES categories.category_id"

int status_id FK "NOT NULL, REFERENCES statuses.status_id"

varchar(100) name "NOT NULL"

varchar(400) description "NOT NULL"

varchar(500) image_url "NULL"

timestamp created_at "NOT NULL, DEFAULT CURRENT_TIMESTAMP"

timestamp updated_at "NULL"

}

AUCTIONS {

int auction_id PK "NOT NULL, GENERATED BY DEFAULT AS IDENTITY"

int product_id FK "NOT NULL, REFERENCES products.product_id"

int status_id FK "NOT NULL, REFERENCES statuses.status_id"

decimal base_price "NOT NULL, DECIMAL(15,5)"

decimal minimum_increment "NOT NULL, DECIMAL(15,5)"

timestamp start_date "NOT NULL"

timestamp end_date "NOT NULL"

timestamp created_at "NOT NULL, DEFAULT CURRENT_TIMESTAMP"

timestamp updated_at "NULL"

}

BIDS {

int bid_id PK "NOT NULL, GENERATED BY DEFAULT AS IDENTITY"

int auction_id FK "NOT NULL, REFERENCES auctions.auction_id"

int participant_id FK "NOT NULL, REFERENCES users.user_id"

decimal amount "NOT NULL, DECIMAL(15,5)"

timestamp bid_date "NOT NULL, DEFAULT CURRENT_TIMESTAMP"

}

AUCTION_CANCELLATIONS {

int auction_id PK,FK "NOT NULL, REFERENCES auctions.auction_id"

int admin_user_id FK "NOT NULL, REFERENCES users.user_id"

jsonb reason_detail "NOT NULL"

timestamp cancelled_at "NOT NULL, DEFAULT CURRENT_TIMESTAMP"

}

STATUS_HISTORY {

bigint history_id PK "NOT NULL, GENERATED BY DEFAULT AS IDENTITY"

varchar(20) entity_type "NOT NULL"

int entity_id "NOT NULL, sin FK"

varchar(40) old_status_code "NULL"

varchar(40) new_status_code "NOT NULL"

int changed_by "NULL, sin FK; NULL si fue automatico"

varchar(100) event_source "NOT NULL, DEFAULT TRIGGER"

timestamp changed_at "NOT NULL, DEFAULT CURRENT_TIMESTAMP"

}

## 8. MOCKUPS

INICIAR SESIÓN

![vista del logeo](/docs/mockups/iniciar_sesion.png)

REGISTRARSE

![vista del registro](/docs/mockups/registrarse.png)

CATÁLOGO
![vista del catalogo](/docs/mockups/catalogo.png)

DETALLE DE LA SUBASTA
![vista del detalle](/docs/mockups/detalle.png)

![vista del detalle](/docs/mockups/detalle_admin.png)

![vista del detalle](/docs/mockups/detalle_activa.png)

PANEL VENDEDOR
![panel del vendedor](/docs/mockups/panel_vendedor.png)
![panel del vendedor](/docs/mockups/panel_vendedor1.png)

PANEL DEL PARTICIPANTE

![panel del participante](/docs/mockups/panel_participante.png)

PANEL ADMINISTRADOR

![panel del administrador](/docs/mockups/admin.png)
![panel del administrador](/docs/mockups/admin2.png)
![panel del administrador](/docs/mockups/admin3.png)