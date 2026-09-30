"""Create the initial auction schema and seed status catalogs."""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "20260930_0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    role_enum = postgresql.ENUM(
        "VENDEDOR", "POSTOR", "ADMIN", name="user_role", create_type=False
    )
    role_enum.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "statuses",
        sa.Column("status_id", sa.Integer(), sa.Identity(), primary_key=True),
        sa.Column("code", sa.String(40), nullable=False, unique=True),
        sa.Column("name", sa.String(60), nullable=False),
        sa.Column("description", sa.String(200)),
        sa.Column("enabled", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True)),
    )
    op.create_table(
        "status_applicability",
        sa.Column("status_id", sa.Integer(), sa.ForeignKey("statuses.status_id", ondelete="RESTRICT"), primary_key=True),
        sa.Column("entity_type", sa.String(20), primary_key=True),
    )
    op.create_table(
        "users",
        sa.Column("user_id", sa.Integer(), sa.Identity(), primary_key=True),
        sa.Column("status_id", sa.Integer(), sa.ForeignKey("statuses.status_id", ondelete="RESTRICT"), nullable=False),
        sa.Column("role", role_enum, nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("alias", sa.String(50), nullable=False, unique=True),
        sa.Column("email", sa.String(150), nullable=False, unique=True),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("address", sa.String(200)),
        sa.Column("phone_number", sa.String(20), nullable=False),
        sa.Column("bid_policy_accepted_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True)),
    )
    op.create_table(
        "categories",
        sa.Column("category_id", sa.Integer(), sa.Identity(), primary_key=True),
        sa.Column("status_id", sa.Integer(), sa.ForeignKey("statuses.status_id", ondelete="RESTRICT"), nullable=False),
        sa.Column("name", sa.String(100), nullable=False, unique=True),
        sa.Column("description", sa.String(400), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True)),
    )
    op.create_table(
        "products",
        sa.Column("product_id", sa.Integer(), sa.Identity(), primary_key=True),
        sa.Column("seller_id", sa.Integer(), sa.ForeignKey("users.user_id", ondelete="RESTRICT"), nullable=False),
        sa.Column("category_id", sa.Integer(), sa.ForeignKey("categories.category_id", ondelete="RESTRICT"), nullable=False),
        sa.Column("status_id", sa.Integer(), sa.ForeignKey("statuses.status_id", ondelete="RESTRICT"), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("brand", sa.Text()),
        sa.Column("description", sa.String(400), nullable=False),
        sa.Column("image_url", sa.String(500), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True)),
    )
    op.create_table(
        "auctions",
        sa.Column("auction_id", sa.Integer(), sa.Identity(), primary_key=True),
        sa.Column("product_id", sa.Integer(), sa.ForeignKey("products.product_id", ondelete="RESTRICT"), nullable=False),
        sa.Column("status_id", sa.Integer(), sa.ForeignKey("statuses.status_id", ondelete="RESTRICT"), nullable=False),
        sa.Column("base_price", sa.Numeric(15, 5), nullable=False),
        sa.Column("minimum_increment", sa.Numeric(15, 5), nullable=False),
        sa.Column("start_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True)),
    )
    op.create_table(
        "bids",
        sa.Column("bid_id", sa.Integer(), sa.Identity(), primary_key=True),
        sa.Column("auction_id", sa.Integer(), sa.ForeignKey("auctions.auction_id", ondelete="RESTRICT"), nullable=False),
        sa.Column("participant_id", sa.Integer(), sa.ForeignKey("users.user_id", ondelete="RESTRICT"), nullable=False),
        sa.Column("amount", sa.Numeric(15, 5), nullable=False),
        sa.Column("bid_date", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "auction_cancellations",
        sa.Column("auction_id", sa.Integer(), sa.ForeignKey("auctions.auction_id", ondelete="RESTRICT"), primary_key=True),
        sa.Column("admin_user_id", sa.Integer(), sa.ForeignKey("users.user_id", ondelete="RESTRICT"), nullable=False),
        sa.Column("reason_detail", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("cancelled_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "status_history",
        sa.Column("history_id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("entity_type", sa.String(20), nullable=False),
        sa.Column("entity_id", sa.Integer(), nullable=False),
        sa.Column("old_status_code", sa.String(40)),
        sa.Column("new_status_code", sa.String(40), nullable=False),
        sa.Column("changed_by", sa.Integer()),
        sa.Column("event_source", sa.String(100), server_default="TRIGGER", nullable=False),
        sa.Column("changed_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    statuses = sa.table(
        "statuses",
        sa.column("status_id", sa.Integer),
        sa.column("code", sa.String),
        sa.column("name", sa.String),
        sa.column("description", sa.String),
        sa.column("enabled", sa.Boolean),
    )
    applicability = sa.table(
        "status_applicability",
        sa.column("status_id", sa.Integer),
        sa.column("entity_type", sa.String),
    )
    status_rows = [
        {"status_id": 1, "code": "ACTIVO", "name": "Activo", "description": "Cuenta, categoría o producto activo", "enabled": True},
        {"status_id": 2, "code": "BLOQUEADO", "name": "Bloqueado", "description": "Cuenta de usuario bloqueada", "enabled": True},
        {"status_id": 3, "code": "DESACTIVADO", "name": "Desactivado", "description": "Cuenta, categoría o producto desactivado", "enabled": True},
        {"status_id": 4, "code": "SUBASTADO", "name": "Subastado", "description": "Producto subastado", "enabled": True},
        {"status_id": 5, "code": "DESACTIVADO_POR_INCUMPLIMIENTO", "name": "Desactivado por incumplimiento", "description": "Producto suspendido por incumplimiento", "enabled": True},
        {"status_id": 6, "code": "PROGRAMADA", "name": "Programada", "description": "Subasta aún no iniciada", "enabled": True},
        {"status_id": 7, "code": "ACTIVA", "name": "Activa", "description": "Subasta que acepta pujas", "enabled": True},
        {"status_id": 8, "code": "CERRADA", "name": "Cerrada", "description": "Subasta cerrada con pujas", "enabled": True},
        {"status_id": 9, "code": "FINALIZADA_SIN_GANADOR", "name": "Finalizada sin ganador", "description": "Subasta cerrada sin pujas", "enabled": True},
        {"status_id": 10, "code": "CANCELADA", "name": "Cancelada", "description": "Subasta cancelada", "enabled": True},
    ]
    op.bulk_insert(statuses, status_rows)
    applicability_rows = [
        {"status_id": 1, "entity_type": "USER"},
        {"status_id": 2, "entity_type": "USER"},
        {"status_id": 3, "entity_type": "USER"},
        {"status_id": 1, "entity_type": "CATEGORY"},
        {"status_id": 3, "entity_type": "CATEGORY"},
        {"status_id": 1, "entity_type": "PRODUCT"},
        {"status_id": 3, "entity_type": "PRODUCT"},
        {"status_id": 4, "entity_type": "PRODUCT"},
        {"status_id": 5, "entity_type": "PRODUCT"},
        {"status_id": 6, "entity_type": "AUCTION"},
        {"status_id": 7, "entity_type": "AUCTION"},
        {"status_id": 8, "entity_type": "AUCTION"},
        {"status_id": 9, "entity_type": "AUCTION"},
        {"status_id": 10, "entity_type": "AUCTION"},
    ]
    op.bulk_insert(applicability, applicability_rows)
    op.execute(
        "SELECT setval(pg_get_serial_sequence('statuses', 'status_id'), "
        "(SELECT MAX(status_id) FROM statuses))"
    )


def downgrade() -> None:
    op.drop_table("status_history")
    op.drop_table("auction_cancellations")
    op.drop_table("bids")
    op.drop_table("auctions")
    op.drop_table("products")
    op.drop_table("categories")
    op.drop_table("users")
    op.drop_table("status_applicability")
    op.drop_table("statuses")
    postgresql.ENUM(name="user_role").drop(op.get_bind(), checkfirst=True)
