"""add_user_profile_fields

Revision ID: 44088048be90
Revises: j1k2l3m4n5o6
Create Date: 2026-01-20 15:50:51.464092

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '44088048be90'
down_revision: Union[str, Sequence[str], None] = 'j1k2l3m4n5o6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Add profile fields
    op.add_column('users', sa.Column('profile_image_url', sa.String(), nullable=True))
    op.add_column('users', sa.Column('email_verified', sa.Boolean(), nullable=False, server_default='false'))
    op.add_column('users', sa.Column('last_login', sa.DateTime(timezone=True), nullable=True))
    
    # Add soft delete fields
    op.add_column('users', sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default='false'))
    op.add_column('users', sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True))
    op.add_column('users', sa.Column('anonymized_at', sa.DateTime(timezone=True), nullable=True))
    
    # Create index on is_deleted for faster queries
    op.create_index('ix_users_is_deleted', 'users', ['is_deleted'])


def downgrade() -> None:
    """Downgrade schema."""
    # Drop index
    op.drop_index('ix_users_is_deleted', table_name='users')
    
    # Drop soft delete fields
    op.drop_column('users', 'anonymized_at')
    op.drop_column('users', 'deleted_at')
    op.drop_column('users', 'is_deleted')
    
    # Drop profile fields
    op.drop_column('users', 'last_login')
    op.drop_column('users', 'email_verified')
    op.drop_column('users', 'profile_image_url')
