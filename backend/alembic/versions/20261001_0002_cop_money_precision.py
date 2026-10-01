"""Use two decimal places for COP amounts."""

from alembic import op
import sqlalchemy as sa


revision = "20261001_0002"
down_revision = "20260930_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column("auctions", "base_price", existing_type=sa.Numeric(15, 5), type_=sa.Numeric(12, 2), existing_nullable=False)
    op.alter_column("auctions", "minimum_increment", existing_type=sa.Numeric(15, 5), type_=sa.Numeric(12, 2), existing_nullable=False)
    op.alter_column("bids", "amount", existing_type=sa.Numeric(15, 5), type_=sa.Numeric(12, 2), existing_nullable=False)


def downgrade() -> None:
    op.alter_column("bids", "amount", existing_type=sa.Numeric(12, 2), type_=sa.Numeric(15, 5), existing_nullable=False)
    op.alter_column("auctions", "minimum_increment", existing_type=sa.Numeric(12, 2), type_=sa.Numeric(15, 5), existing_nullable=False)
    op.alter_column("auctions", "base_price", existing_type=sa.Numeric(12, 2), type_=sa.Numeric(15, 5), existing_nullable=False)
