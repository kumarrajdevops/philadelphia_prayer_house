"""add prayer_type location join_info columns

Revision ID: d4e5f6a1b2c3
Revises: a1b2c3d4e5f6
Create Date: 2026-01-11 13:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd4e5f6a1b2c3'
down_revision: Union[str, None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add prayer_type column with default value 'offline'
    op.add_column(
        'prayers',
        sa.Column('prayer_type', sa.String(), nullable=True, server_default='offline')
    )
    
    # Backfill existing prayers to 'offline' (safe default)
    op.execute("UPDATE prayers SET prayer_type = 'offline' WHERE prayer_type IS NULL")
    
    # Make prayer_type NOT NULL after backfill
    op.alter_column('prayers', 'prayer_type', nullable=False, server_default='offline')
    
    # Add index for faster filtering
    op.create_index('ix_prayers_prayer_type', 'prayers', ['prayer_type'])
    
    # Add location column (nullable, for offline prayers)
    op.add_column(
        'prayers',
        sa.Column('location', sa.String(), nullable=True)
    )
    
    # Add join_info column (nullable, for online prayers)
    op.add_column(
        'prayers',
        sa.Column('join_info', sa.String(), nullable=True)
    )


def downgrade() -> None:
    # Remove join_info column
    op.drop_column('prayers', 'join_info')
    
    # Remove location column
    op.drop_column('prayers', 'location')
    
    # Remove index
    op.drop_index('ix_prayers_prayer_type', table_name='prayers')
    
    # Remove prayer_type column
    op.drop_column('prayers', 'prayer_type')

