"""add_member_username_to_prayer_requests

Revision ID: cf36ab0591ab
Revises: ff0486d03e24
Create Date: 2026-01-27 19:14:32.145430

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'cf36ab0591ab'
down_revision: Union[str, Sequence[str], None] = 'ff0486d03e24'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Add member_username column (nullable first for existing data)
    op.add_column('prayer_requests', sa.Column('member_username', sa.String(), nullable=True))
    
    # Backfill existing prayer requests with user's current username
    # This preserves the username even if user is later deleted
    op.execute("""
        UPDATE prayer_requests
        SET member_username = (
            SELECT username FROM users WHERE users.id = prayer_requests.user_id
        )
        WHERE member_username IS NULL
    """)
    
    # Now make it NOT NULL since all rows have values
    op.alter_column('prayer_requests', 'member_username', nullable=False)


def downgrade() -> None:
    """Downgrade schema."""
    # Remove member_username column
    op.drop_column('prayer_requests', 'member_username')
