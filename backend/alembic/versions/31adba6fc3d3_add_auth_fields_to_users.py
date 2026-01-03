"""add auth fields to users

Revision ID: 31adba6fc3d3
Revises: 3113d78baa38
Create Date: 2026-01-02 21:12:28.534390
"""

from alembic import op
import sqlalchemy as sa


revision = "31adba6fc3d3"
down_revision = "3113d78baa38"
branch_labels = None
depends_on = None


def upgrade():
    # 1️⃣ Add columns as NULLABLE first
    op.add_column(
        "users",
        sa.Column("username", sa.String(), nullable=True)
    )
    op.add_column(
        "users",
        sa.Column("hashed_password", sa.String(), nullable=True)
    )
    op.add_column(
        "users",
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        )
    )

    # 2️⃣ Backfill existing users safely
    op.execute(
        """
        UPDATE users
        SET
            username = 'user_' || id,
            hashed_password = 'TEMP_PASSWORD'
        WHERE username IS NULL;
        """
    )

    # 3️⃣ Enforce NOT NULL after backfill
    op.alter_column("users", "username", nullable=False)
    op.alter_column("users", "hashed_password", nullable=False)

    # 4️⃣ Add unique constraint
    op.create_unique_constraint(
        "uq_users_username",
        "users",
        ["username"]
    )


def downgrade():
    op.drop_constraint("uq_users_username", "users", type_="unique")
    op.drop_column("users", "is_active")
    op.drop_column("users", "hashed_password")
    op.drop_column("users", "username")
