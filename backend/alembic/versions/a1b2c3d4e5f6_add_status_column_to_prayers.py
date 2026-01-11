"""add status column to prayers

Revision ID: a1b2c3d4e5f6
Revises: 215a6df83493
Create Date: 2026-01-11 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from datetime import datetime


# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, None] = '215a6df83493'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add status column with default value (nullable initially)
    op.add_column(
        'prayers',
        sa.Column('status', sa.String(), nullable=True, server_default='upcoming')
    )
    
    # Compute status for all existing prayers
    # Default all to 'upcoming' (safe default, will be computed dynamically on read)
    # For migration, we set all to 'upcoming' - status will be computed dynamically when prayers are read
    op.execute("UPDATE prayers SET status = 'upcoming' WHERE status IS NULL")
    
    # Make status NOT NULL after backfill
    op.alter_column('prayers', 'status', nullable=False, server_default='upcoming')
    
    # Add index for faster filtering
    op.create_index('ix_prayers_status', 'prayers', ['status'])


def downgrade() -> None:
    # Remove index
    op.drop_index('ix_prayers_status', table_name='prayers')
    
    # Remove status column
    op.drop_column('prayers', 'status')

