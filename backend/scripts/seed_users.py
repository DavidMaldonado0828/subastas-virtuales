import os
import sys
from datetime import UTC, datetime

from dotenv import load_dotenv
from sqlalchemy.exc import IntegrityError

from app.core.config import BACKEND_DIR
from app.core.enums import EntityType, UserRole
from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models.user import User
from app.repositories import users as user_repository

SEED_USERS = (
    {
        "role": UserRole.ADMIN,
        "name": "Administrador inicial",
        "alias": "admin-inicial",
        "email": "admin-inicial@example.com",
        "phone_number": "+570000000001",
        "password_variable": "SEED_ADMIN_PASSWORD",
    },
    {
        "role": UserRole.VENDEDOR,
        "name": "Vendedor inicial",
        "alias": "vendedor-inicial",
        "email": "vendedor-inicial@example.com",
        "phone_number": "+570000000002",
        "password_variable": "SEED_SELLER_PASSWORD",
    },
    {
        "role": UserRole.POSTOR,
        "name": "Postor inicial",
        "alias": "postor-inicial",
        "email": "postor-inicial@example.com",
        "phone_number": "+570000000003",
        "password_variable": "SEED_POSTOR_PASSWORD",
    },
)


def main() -> int:
    load_dotenv(BACKEND_DIR / ".env")
    passwords = {user["password_variable"]: os.getenv(user["password_variable"]) for user in SEED_USERS}
    missing = [name for name, value in passwords.items() if not value]
    if missing:
        print("Faltan variables de entorno requeridas: " + ", ".join(missing), file=sys.stderr)
        return 2
    if any(not 8 <= len(value or "") <= 128 for value in passwords.values()):
        print("Cada contraseña de seed debe tener entre 8 y 128 caracteres.", file=sys.stderr)
        return 2

    with SessionLocal() as session:
        active_status = user_repository.get_status_for_entity(
            session, "ACTIVO", EntityType.USER.value
        )
        if active_status is None:
            print("Ejecuta primero las migraciones de Alembic.", file=sys.stderr)
            return 2

        created_count = 0
        for seed_user in SEED_USERS:
            existing = user_repository.get_by_email(session, seed_user["email"])
            if existing:
                continue
            session.add(
                User(
                    status_id=active_status.status_id,
                    role=seed_user["role"],
                    name=seed_user["name"],
                    alias=seed_user["alias"],
                    email=seed_user["email"],
                    password_hash=hash_password(passwords[seed_user["password_variable"]] or ""),
                    phone_number=seed_user["phone_number"],
                    bid_policy_accepted_at=(
                        datetime.now(UTC) if seed_user["role"] == UserRole.POSTOR else None
                    ),
                )
            )
            created_count += 1
        try:
            session.commit()
        except IntegrityError:
            session.rollback()
            print("No se pudieron crear las cuentas de seed.", file=sys.stderr)
            return 1

    print(f"Seed completado; cuentas nuevas: {created_count}.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        print("No se pudo completar el seed; revisa configuración y conectividad.", file=sys.stderr)
        raise SystemExit(1) from None
