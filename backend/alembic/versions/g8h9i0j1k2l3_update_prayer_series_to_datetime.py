"""update prayer series to datetime

Revision ID: g8h9i0j1k2l3
Revises: f7g8h9i0j1k2
Create Date: 2026-01-18 13:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'g8h9i0j1k2l3'
down_revision: Union[str, None] = 'f7g8h9i0j1k2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    connection = op.get_bind()
    
    # Check if start_datetime column exists in prayer_series
    result = connection.execute(sa.text("""
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = 'prayer_series' AND column_name = 'start_datetime'
    """))
    has_start_datetime = result.fetchone() is not None
    
    if not has_start_datetime:
        # Add new datetime columns (nullable initially for prayer_series)
        # Since prayer_series is likely empty (new feature), we can make them non-nullable
        op.add_column('prayer_series', sa.Column('start_datetime', sa.DateTime(timezone=True), nullable=True))
        op.add_column('prayer_series', sa.Column('end_datetime', sa.DateTime(timezone=True), nullable=True))
        
        # For prayer_series, if there's no data, make columns non-nullable
        # Check if table has any rows
        count_result = connection.execute(sa.text("SELECT COUNT(*) FROM prayer_series"))
        row_count = count_result.scalar()
        
        if row_count == 0:
            # No data, safe to make non-nullable
            op.alter_column('prayer_series', 'start_datetime', nullable=False)
            op.alter_column('prayer_series', 'end_datetime', nullable=False)
        else:
            # Has data - we'd need to migrate from old columns, but for now keep nullable
            # This is unlikely since prayer_series is new
            pass
        
        # Drop old columns if they exist
        try:
            op.drop_column('prayer_series', 'start_time')
        except Exception:
            pass
        try:
            op.drop_column('prayer_series', 'end_time')
        except Exception:
            pass
    
    # Check prayer_occurrences table
    result = connection.execute(sa.text("""
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = 'prayer_occurrences' AND column_name = 'start_datetime'
    """))
    has_occurrence_start_datetime = result.fetchone() is not None
    
    if not has_occurrence_start_datetime:
        # Add new datetime columns (nullable initially)
        op.add_column('prayer_occurrences', sa.Column('start_datetime', sa.DateTime(timezone=True), nullable=True))
        op.add_column('prayer_occurrences', sa.Column('end_datetime', sa.DateTime(timezone=True), nullable=True))
        
        # Migrate data from prayer_date + start_time + end_time to start_datetime + end_datetime
        # Check if old columns exist
        old_cols_result = connection.execute(sa.text("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name = 'prayer_occurrences' 
            AND column_name IN ('prayer_date', 'start_time', 'end_time')
        """))
        old_cols = [row[0] for row in old_cols_result.fetchall()]
        
        if 'prayer_date' in old_cols and 'start_time' in old_cols and 'end_time' in old_cols:
            # Migrate existing data
            op.execute(sa.text("""
                UPDATE prayer_occurrences
                SET start_datetime = (prayer_date + start_time)::timestamp with time zone,
                    end_datetime = (prayer_date + end_time)::timestamp with time zone
                WHERE start_datetime IS NULL OR end_datetime IS NULL
            """))
        
        # Make columns non-nullable
        op.alter_column('prayer_occurrences', 'start_datetime', nullable=False)
        op.alter_column('prayer_occurrences', 'end_datetime', nullable=False)
        
        # Create indexes for new columns (if they don't exist)
        try:
            op.create_index('ix_prayer_occurrences_start_datetime', 'prayer_occurrences', ['start_datetime'])
        except Exception:
            pass
        try:
            op.create_index('ix_prayer_occurrences_end_datetime', 'prayer_occurrences', ['end_datetime'])
        except Exception:
            pass
        
        # Drop old columns if they exist
        if 'prayer_date' in old_cols:
            try:
                op.drop_index('ix_prayer_occurrences_prayer_date', table_name='prayer_occurrences')
            except Exception:
                pass
            op.drop_column('prayer_occurrences', 'prayer_date')
        if 'start_time' in old_cols:
            op.drop_column('prayer_occurrences', 'start_time')
        if 'end_time' in old_cols:
            op.drop_column('prayer_occurrences', 'end_time')


def downgrade() -> None:
    # This downgrade would restore the old schema if needed
    # For now, we'll leave it minimal since this is a forward migration
    pass
