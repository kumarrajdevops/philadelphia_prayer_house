"""add_phone_email_and_otp_table

Revision ID: b8cb925196a2
Revises: 31adba6fc3d3
Create Date: 2026-01-03 14:09:44.141895

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b8cb925196a2'
down_revision: Union[str, Sequence[str], None] = '31adba6fc3d3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Add phone and email columns to users table
    op.add_column("users", sa.Column("phone", sa.String(), nullable=True))
    op.add_column("users", sa.Column("email", sa.String(), nullable=True))
    op.add_column("users", sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True))
    op.add_column("users", sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True))
    
    # Make hashed_password nullable (for OTP-only users)
    op.alter_column("users", "hashed_password", nullable=True)
    
    # Create indexes for phone and email
    op.create_index("ix_users_phone", "users", ["phone"], unique=True)
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    
    # Create OTP table
    op.create_table(
        "otps",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("phone", sa.String(), nullable=True),
        sa.Column("email", sa.String(), nullable=True),
        sa.Column("otp_code", sa.String(), nullable=False),
        sa.Column("is_verified", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    
    # Create indexes for OTP table
    op.create_index("ix_otps_id", "otps", ["id"])
    op.create_index("ix_otps_phone", "otps", ["phone"])
    op.create_index("ix_otps_email", "otps", ["email"])
    op.create_index("ix_otps_expires_at", "otps", ["expires_at"])
    op.create_index("ix_otps_phone_email", "otps", ["phone", "email"])


def downgrade() -> None:
    """Downgrade schema."""
    # Drop OTP table
    op.drop_index("ix_otps_phone_email", table_name="otps")
    op.drop_index("ix_otps_expires_at", table_name="otps")
    op.drop_index("ix_otps_email", table_name="otps")
    op.drop_index("ix_otps_phone", table_name="otps")
    op.drop_index("ix_otps_id", table_name="otps")
    op.drop_table("otps")
    
    # Drop indexes from users
    op.drop_index("ix_users_email", table_name="users")
    op.drop_index("ix_users_phone", table_name="users")
    
    # Drop columns from users
    op.drop_column("users", "updated_at")
    op.drop_column("users", "created_at")
    op.drop_column("users", "email")
    op.drop_column("users", "phone")
    
    # Make hashed_password NOT NULL again
    op.alter_column("users", "hashed_password", nullable=False)
