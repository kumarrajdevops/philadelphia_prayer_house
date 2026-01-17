"""add events tables

Revision ID: e5f6a7b8c9d0
Revises: d4e5f6a1b2c3
Create Date: 2026-01-15 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'e5f6a7b8c9d0'
down_revision: Union[str, None] = 'd4e5f6a1b2c3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    connection = op.get_bind()
    
    # Check if tables already exist (idempotent migration)
    inspector = sa.inspect(connection)
    event_series_exists = inspector.has_table('event_series')
    event_occurrences_exists = inspector.has_table('event_occurrences')
    
    if not event_series_exists:
        # Create event_series table (template/recurrence definition)
        op.create_table(
            'event_series',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('title', sa.String(), nullable=False),
            sa.Column('description', sa.String(), nullable=True),
            sa.Column('event_type', sa.String(), nullable=False),  # online, offline
            sa.Column('location', sa.String(), nullable=True),  # Required for offline
            sa.Column('join_info', sa.String(), nullable=True),  # Required for online
            sa.Column('recurrence_type', sa.String(), nullable=False, server_default='none'),  # none, daily, weekly, monthly
            sa.Column('recurrence_days', sa.String(), nullable=True),  # For weekly: comma-separated days (0=Mon, 6=Sun)
            sa.Column('recurrence_end_date', sa.Date(), nullable=True),  # Optional end date
            sa.Column('recurrence_count', sa.Integer(), nullable=True),  # Optional: end after N occurrences
            sa.Column('created_by', sa.Integer(), nullable=False),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(timezone=True), onupdate=sa.func.now()),
            sa.PrimaryKeyConstraint('id'),
            sa.ForeignKeyConstraint(['created_by'], ['users.id'], ondelete='CASCADE'),
        )
        op.create_index('ix_event_series_created_by', 'event_series', ['created_by'])
        op.create_index('ix_event_series_is_active', 'event_series', ['is_active'])
    
    if not event_occurrences_exists:
        # Create event_occurrences table (actual events that everyone sees)
        op.create_table(
            'event_occurrences',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('event_series_id', sa.Integer(), nullable=False),
            sa.Column('title', sa.String(), nullable=False),  # Snapshot from series
            sa.Column('description', sa.String(), nullable=True),  # Snapshot from series
            sa.Column('event_type', sa.String(), nullable=False),  # Snapshot from series
            sa.Column('location', sa.String(), nullable=True),  # Snapshot from series
            sa.Column('join_info', sa.String(), nullable=True),  # Snapshot from series
            sa.Column('start_datetime', sa.DateTime(timezone=True), nullable=False),
            sa.Column('end_datetime', sa.DateTime(timezone=True), nullable=False),
            sa.Column('status', sa.String(), nullable=False, server_default='upcoming', index=True),  # upcoming, ongoing, completed
            sa.Column('recurrence_type', sa.String(), nullable=True),  # For label display: weekly/monthly/daily
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(timezone=True), onupdate=sa.func.now()),
            sa.PrimaryKeyConstraint('id'),
            sa.ForeignKeyConstraint(['event_series_id'], ['event_series.id'], ondelete='CASCADE'),
        )
        op.create_index('ix_event_occurrences_event_series_id', 'event_occurrences', ['event_series_id'])
        op.create_index('ix_event_occurrences_start_datetime', 'event_occurrences', ['start_datetime'])
        op.create_index('ix_event_occurrences_end_datetime', 'event_occurrences', ['end_datetime'])
        op.create_index('ix_event_occurrences_status', 'event_occurrences', ['status'])


def downgrade() -> None:
    op.drop_index('ix_event_occurrences_status', table_name='event_occurrences')
    op.drop_index('ix_event_occurrences_end_datetime', table_name='event_occurrences')
    op.drop_index('ix_event_occurrences_start_datetime', table_name='event_occurrences')
    op.drop_index('ix_event_occurrences_event_series_id', table_name='event_occurrences')
    op.drop_table('event_occurrences')
    op.drop_index('ix_event_series_is_active', table_name='event_series')
    op.drop_index('ix_event_series_created_by', table_name='event_series')
    op.drop_table('event_series')

