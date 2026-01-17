"""add prayer series tables

Revision ID: f7g8h9i0j1k2
Revises: e5f6a7b8c9d0
Create Date: 2026-01-18 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'f7g8h9i0j1k2'
down_revision: Union[str, None] = 'e5f6a7b8c9d0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    connection = op.get_bind()
    
    # Check if tables already exist (idempotent migration)
    inspector = sa.inspect(connection)
    prayer_series_exists = inspector.has_table('prayer_series')
    prayer_occurrences_exists = inspector.has_table('prayer_occurrences')
    
    if not prayer_series_exists:
        # Create prayer_series table (template/recurrence definition)
        op.create_table(
            'prayer_series',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('title', sa.String(), nullable=False),
            sa.Column('prayer_type', sa.String(), nullable=False),  # online, offline
            sa.Column('location', sa.String(), nullable=True),  # Required for offline
            sa.Column('join_info', sa.String(), nullable=True),  # Required for online
            sa.Column('recurrence_type', sa.String(), nullable=False, server_default='none'),  # none, daily, weekly, monthly
            sa.Column('recurrence_days', sa.String(), nullable=True),  # For weekly: comma-separated days (0=Mon, 6=Sun)
            sa.Column('recurrence_end_date', sa.Date(), nullable=True),  # Optional end date
            sa.Column('recurrence_count', sa.Integer(), nullable=True),  # Optional: end after N occurrences
            sa.Column('start_datetime', sa.DateTime(timezone=True), nullable=False),  # First occurrence start datetime (supports multi-day)
            sa.Column('end_datetime', sa.DateTime(timezone=True), nullable=False),  # First occurrence end datetime (supports multi-day)
            sa.Column('created_by', sa.Integer(), nullable=False),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(timezone=True), onupdate=sa.func.now()),
            sa.PrimaryKeyConstraint('id'),
            sa.ForeignKeyConstraint(['created_by'], ['users.id'], ondelete='CASCADE'),
        )
        op.create_index('ix_prayer_series_created_by', 'prayer_series', ['created_by'])
        op.create_index('ix_prayer_series_is_active', 'prayer_series', ['is_active'])
    
    if not prayer_occurrences_exists:
        # Create prayer_occurrences table (actual prayers that everyone sees)
        op.create_table(
            'prayer_occurrences',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('prayer_series_id', sa.Integer(), nullable=False),
            sa.Column('title', sa.String(), nullable=False),  # Snapshot from series
            sa.Column('prayer_type', sa.String(), nullable=False),  # Snapshot from series
            sa.Column('location', sa.String(), nullable=True),  # Snapshot from series
            sa.Column('join_info', sa.String(), nullable=True),  # Snapshot from series
            sa.Column('start_datetime', sa.DateTime(timezone=True), nullable=False, index=True),  # Start datetime (supports multi-day)
            sa.Column('end_datetime', sa.DateTime(timezone=True), nullable=False, index=True),  # End datetime (supports multi-day)
            sa.Column('status', sa.String(), nullable=False, server_default='upcoming', index=True),  # upcoming, ongoing, completed
            sa.Column('recurrence_type', sa.String(), nullable=True),  # For label display: daily/weekly/monthly
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(timezone=True), onupdate=sa.func.now()),
            sa.PrimaryKeyConstraint('id'),
            sa.ForeignKeyConstraint(['prayer_series_id'], ['prayer_series.id'], ondelete='CASCADE'),
        )
        op.create_index('ix_prayer_occurrences_prayer_series_id', 'prayer_occurrences', ['prayer_series_id'])
        op.create_index('ix_prayer_occurrences_start_datetime', 'prayer_occurrences', ['start_datetime'])
        op.create_index('ix_prayer_occurrences_end_datetime', 'prayer_occurrences', ['end_datetime'])
        op.create_index('ix_prayer_occurrences_status', 'prayer_occurrences', ['status'])


def downgrade() -> None:
    op.drop_index('ix_prayer_occurrences_status', table_name='prayer_occurrences')
    op.drop_index('ix_prayer_occurrences_end_datetime', table_name='prayer_occurrences')
    op.drop_index('ix_prayer_occurrences_start_datetime', table_name='prayer_occurrences')
    op.drop_index('ix_prayer_occurrences_prayer_series_id', table_name='prayer_occurrences')
    op.drop_table('prayer_occurrences')
    op.drop_index('ix_prayer_series_is_active', table_name='prayer_series')
    op.drop_index('ix_prayer_series_created_by', table_name='prayer_series')
    op.drop_table('prayer_series')

