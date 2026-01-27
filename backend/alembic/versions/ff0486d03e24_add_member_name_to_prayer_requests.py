"""add_member_name_to_prayer_requests

Revision ID: ff0486d03e24
Revises: 44088048be90
Create Date: 2026-01-27 19:04:23.590292

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ff0486d03e24'
down_revision: Union[str, Sequence[str], None] = '44088048be90'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Add member_name column (nullable first for existing data)
    op.add_column('prayer_requests', sa.Column('member_name', sa.String(), nullable=True))
    
    # Backfill existing prayer requests with user's current name
    # This preserves the name even if user is later deleted
    op.execute("""
        UPDATE prayer_requests
        SET member_name = (
            SELECT name FROM users WHERE users.id = prayer_requests.user_id
        )
        WHERE member_name IS NULL
    """)
    
    # Now make it NOT NULL since all rows have values
    op.alter_column('prayer_requests', 'member_name', nullable=False)


def downgrade() -> None:
    """Downgrade schema."""
    # Remove member_name column
    op.drop_column('prayer_requests', 'member_name')
