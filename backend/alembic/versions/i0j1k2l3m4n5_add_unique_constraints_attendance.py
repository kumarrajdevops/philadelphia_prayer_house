"""add unique constraints to attendance

Revision ID: i0j1k2l3m4n5
Revises: h9i0j1k2l3m4
Create Date: 2026-01-18 15:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'i0j1k2l3m4n5'
down_revision: Union[str, None] = 'h9i0j1k2l3m4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    connection = op.get_bind()
    
    # Check if attendance table exists
    inspector = sa.inspect(connection)
    attendance_exists = inspector.has_table('attendance')
    
    if attendance_exists:
        # STEP 1: Clean up existing duplicates before creating unique constraints
        # Keep only the earliest attendance record for each user+occurrence combination
        
        # Remove duplicates for prayer_occurrence_id
        op.execute("""
            DELETE FROM attendance a1
            WHERE a1.prayer_occurrence_id IS NOT NULL
            AND EXISTS (
                SELECT 1 FROM attendance a2
                WHERE a2.user_id = a1.user_id
                AND a2.prayer_occurrence_id = a1.prayer_occurrence_id
                AND a2.id < a1.id  -- Keep the record with the smallest id (earliest)
            )
        """)
        
        # Remove duplicates for event_occurrence_id
        op.execute("""
            DELETE FROM attendance a1
            WHERE a1.event_occurrence_id IS NOT NULL
            AND EXISTS (
                SELECT 1 FROM attendance a2
                WHERE a2.user_id = a1.user_id
                AND a2.event_occurrence_id = a1.event_occurrence_id
                AND a2.id < a1.id  -- Keep the record with the smallest id (earliest)
            )
        """)
        
        # STEP 2: Check if unique indexes already exist
        indexes = inspector.get_indexes('attendance')
        index_names = [idx['name'] for idx in indexes]
        
        # STEP 3: Create partial unique indexes to prevent future duplicates
        # PostgreSQL partial unique index syntax
        if 'uq_attendance_user_prayer' not in index_names:
            op.execute("""
                CREATE UNIQUE INDEX uq_attendance_user_prayer 
                ON attendance (user_id, prayer_occurrence_id) 
                WHERE prayer_occurrence_id IS NOT NULL
            """)
        
        if 'uq_attendance_user_event' not in index_names:
            op.execute("""
                CREATE UNIQUE INDEX uq_attendance_user_event 
                ON attendance (user_id, event_occurrence_id) 
                WHERE event_occurrence_id IS NOT NULL
            """)


def downgrade() -> None:
    connection = op.get_bind()
    
    # Check if attendance table exists
    inspector = sa.inspect(connection)
    attendance_exists = inspector.has_table('attendance')
    
    if attendance_exists:
        # Drop unique indexes
        indexes = inspector.get_indexes('attendance')
        index_names = [idx['name'] for idx in indexes]
        
        if 'uq_attendance_user_prayer' in index_names:
            op.drop_index('uq_attendance_user_prayer', table_name='attendance')
        
        if 'uq_attendance_user_event' in index_names:
            op.drop_index('uq_attendance_user_event', table_name='attendance')
