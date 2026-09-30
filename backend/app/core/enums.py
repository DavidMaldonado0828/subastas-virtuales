from enum import Enum


class UserRole(str, Enum):
    VENDEDOR = "VENDEDOR"
    POSTOR = "POSTOR"
    ADMIN = "ADMIN"


class EntityType(str, Enum):
    USER = "USER"
    CATEGORY = "CATEGORY"
    PRODUCT = "PRODUCT"
    AUCTION = "AUCTION"


class UserStatus(str, Enum):
    ACTIVO = "ACTIVO"
    BLOQUEADO = "BLOQUEADO"
    DESACTIVADO = "DESACTIVADO"


class CategoryStatus(str, Enum):
    ACTIVO = "ACTIVO"
    DESACTIVADO = "DESACTIVADO"


class ProductStatus(str, Enum):
    ACTIVO = "ACTIVO"
    DESACTIVADO = "DESACTIVADO"
    SUBASTADO = "SUBASTADO"
    DESACTIVADO_POR_INCUMPLIMIENTO = "DESACTIVADO_POR_INCUMPLIMIENTO"


class AuctionStatus(str, Enum):
    PROGRAMADA = "PROGRAMADA"
    ACTIVA = "ACTIVA"
    CERRADA = "CERRADA"
    FINALIZADA_SIN_GANADOR = "FINALIZADA_SIN_GANADOR"
    CANCELADA = "CANCELADA"
