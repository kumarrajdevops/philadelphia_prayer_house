"""make prayers.created_by not null

Revision ID: 215a6df83493
Revises: b8cb925196a2
Create Date: 2026-01-03 14:30:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = "215a6df83493"
down_revision = "b8cb925196a2"
branch_labels = None
depends_on = None


def upgrade():
    # Ensure no orphan prayers exist
    op.execute(
        """
        DELETE FROM prayers
        WHERE created_by IS NULL;
        """
    )

    # Enforce NOT NULL
    op.alter_column(
        "prayers",
        "created_by",
        existing_type=sa.Integer(),
        nullable=False,
    )


def downgrade():
    op.alter_column(
        "prayers",
        "created_by",
        existing_type=sa.Integer(),
        nullable=True,
    )
