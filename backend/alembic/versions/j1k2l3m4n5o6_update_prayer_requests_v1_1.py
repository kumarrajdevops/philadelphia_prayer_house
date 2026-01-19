"""update prayer requests v1.1 public private

Revision ID: j1k2l3m4n5o6
Revises: i0j1k2l3m4n5
Create Date: 2026-01-20 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'j1k2l3m4n5o6'
down_revision: Union[str, None] = 'i0j1k2l3m4n5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    connection = op.get_bind()
    inspector = sa.inspect(connection)
    
    # Check if prayer_requests table exists
    if not inspector.has_table('prayer_requests'):
        return  # Table doesn't exist, skip migration
    
    # Step 1: Add new columns first
    with op.batch_alter_table('prayer_requests', schema=None) as batch_op:
        # Add request_type column (default to 'public' for existing records)
        if 'request_type' not in [col['name'] for col in inspector.get_columns('prayer_requests')]:
            batch_op.add_column(sa.Column('request_type', sa.String(), nullable=False, server_default='public'))
        
        # Add prayed_at column
        if 'prayed_at' not in [col['name'] for col in inspector.get_columns('prayer_requests')]:
            batch_op.add_column(sa.Column('prayed_at', sa.DateTime(timezone=True), nullable=True))
        
        # Add archived_at column
        if 'archived_at' not in [col['name'] for col in inspector.get_columns('prayer_requests')]:
            batch_op.add_column(sa.Column('archived_at', sa.DateTime(timezone=True), nullable=True))
    
    # Step 2: Create indexes after columns are added (refresh inspector)
    inspector = sa.inspect(connection)
    existing_columns = [col['name'] for col in inspector.get_columns('prayer_requests')]
    existing_indexes = [idx['name'] for idx in inspector.get_indexes('prayer_requests')]
    
    if 'request_type' in existing_columns and 'ix_prayer_requests_request_type' not in existing_indexes:
        op.create_index('ix_prayer_requests_request_type', 'prayer_requests', ['request_type'], unique=False)
    if 'prayed_at' in existing_columns and 'ix_prayer_requests_prayed_at' not in existing_indexes:
        op.create_index('ix_prayer_requests_prayed_at', 'prayer_requests', ['prayed_at'], unique=False)
    if 'archived_at' in existing_columns and 'ix_prayer_requests_archived_at' not in existing_indexes:
        op.create_index('ix_prayer_requests_archived_at', 'prayer_requests', ['archived_at'], unique=False)
    
    # Step 3: Convert is_anonymous to request_type (after column is created)
    # Refresh inspector to get latest column list
    inspector = sa.inspect(connection)
    if 'is_anonymous' in [col['name'] for col in inspector.get_columns('prayer_requests')]:
        op.execute("""
            UPDATE prayer_requests 
            SET request_type = CASE 
                WHEN is_anonymous = true THEN 'private'
                ELSE 'public'
            END
        """)
    
    # Step 4: Update status: 'new' -> 'submitted'
    op.execute("""
        UPDATE prayer_requests 
        SET status = 'submitted' 
        WHERE status = 'new'
    """)
    
    # Step 5: Make user_id NOT NULL (pastor must always know who sent it)
    # First, update any NULL user_id to a default (if any exist, which shouldn't)
    op.execute("""
        UPDATE prayer_requests 
        SET user_id = (SELECT id FROM users LIMIT 1)
        WHERE user_id IS NULL
    """)
    
    # Then alter column to NOT NULL
    # Refresh inspector before checking for is_anonymous
    inspector = sa.inspect(connection)
    with op.batch_alter_table('prayer_requests', schema=None) as batch_op:
        batch_op.alter_column('user_id', nullable=False)
        
        # Step 6: Drop is_anonymous column (replaced by request_type)
        if 'is_anonymous' in [col['name'] for col in inspector.get_columns('prayer_requests')]:
            batch_op.drop_column('is_anonymous')


def downgrade() -> None:
    connection = op.get_bind()
    inspector = sa.inspect(connection)
    
    if not inspector.has_table('prayer_requests'):
        return
    
    with op.batch_alter_table('prayer_requests', schema=None) as batch_op:
        # Restore is_anonymous column
        if 'is_anonymous' not in [col['name'] for col in inspector.get_columns('prayer_requests')]:
            batch_op.add_column(sa.Column('is_anonymous', sa.Boolean(), nullable=False, server_default='false'))
            # Convert request_type back to is_anonymous
            op.execute("""
                UPDATE prayer_requests 
                SET is_anonymous = CASE 
                    WHEN request_type = 'private' THEN true
                    ELSE false
                END
            """)
        
        # Drop new columns
        if 'request_type' in [col['name'] for col in inspector.get_columns('prayer_requests')]:
            batch_op.drop_index('ix_prayer_requests_request_type')
            batch_op.drop_column('request_type')
        
        if 'prayed_at' in [col['name'] for col in inspector.get_columns('prayer_requests')]:
            batch_op.drop_index('ix_prayer_requests_prayed_at')
            batch_op.drop_column('prayed_at')
        
        if 'archived_at' in [col['name'] for col in inspector.get_columns('prayer_requests')]:
            batch_op.drop_index('ix_prayer_requests_archived_at')
            batch_op.drop_column('archived_at')
        
        # Revert status: 'submitted' -> 'new'
        op.execute("""
            UPDATE prayer_requests 
            SET status = 'new' 
            WHERE status = 'submitted'
        """)
        
        # Make user_id nullable again
        batch_op.alter_column('user_id', nullable=True)
