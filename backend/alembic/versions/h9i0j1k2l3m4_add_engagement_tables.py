"""add engagement tables

Revision ID: h9i0j1k2l3m4
Revises: g8h9i0j1k2l3
Create Date: 2026-01-18 14:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'h9i0j1k2l3m4'
down_revision: Union[str, None] = 'g8h9i0j1k2l3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    connection = op.get_bind()
    inspector = sa.inspect(connection)
    
    # Check if tables already exist (idempotent migration)
    attendance_exists = inspector.has_table('attendance')
    favorites_exists = inspector.has_table('favorites')
    reminder_settings_exists = inspector.has_table('reminder_settings')
    prayer_requests_exists = inspector.has_table('prayer_requests')
    
    # Create attendance table
    if not attendance_exists:
        op.create_table(
            'attendance',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('user_id', sa.Integer(), nullable=False),
            sa.Column('prayer_occurrence_id', sa.Integer(), nullable=True),
            sa.Column('event_occurrence_id', sa.Integer(), nullable=True),
            sa.Column('joined_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
            sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['prayer_occurrence_id'], ['prayer_occurrences.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['event_occurrence_id'], ['event_occurrences.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_attendance_id'), 'attendance', ['id'], unique=False)
        op.create_index(op.f('ix_attendance_user_id'), 'attendance', ['user_id'], unique=False)
        op.create_index(op.f('ix_attendance_prayer_occurrence_id'), 'attendance', ['prayer_occurrence_id'], unique=False)
        op.create_index(op.f('ix_attendance_event_occurrence_id'), 'attendance', ['event_occurrence_id'], unique=False)
        op.create_index(op.f('ix_attendance_joined_at'), 'attendance', ['joined_at'], unique=False)
        op.create_index('ix_attendance_user_prayer', 'attendance', ['user_id', 'prayer_occurrence_id'], unique=False)
        op.create_index('ix_attendance_user_event', 'attendance', ['user_id', 'event_occurrence_id'], unique=False)

    # Create favorites table
    if not favorites_exists:
        op.create_table(
            'favorites',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('user_id', sa.Integer(), nullable=False),
            sa.Column('prayer_series_id', sa.Integer(), nullable=True),
            sa.Column('event_series_id', sa.Integer(), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
            sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['prayer_series_id'], ['prayer_series.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['event_series_id'], ['event_series.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_favorites_id'), 'favorites', ['id'], unique=False)
        op.create_index(op.f('ix_favorites_user_id'), 'favorites', ['user_id'], unique=False)
        op.create_index(op.f('ix_favorites_prayer_series_id'), 'favorites', ['prayer_series_id'], unique=False)
        op.create_index(op.f('ix_favorites_event_series_id'), 'favorites', ['event_series_id'], unique=False)
        op.create_index('ix_favorites_user_prayer', 'favorites', ['user_id', 'prayer_series_id'], unique=True)
        op.create_index('ix_favorites_user_event', 'favorites', ['user_id', 'event_series_id'], unique=True)

    # Create reminder_settings table
    if not reminder_settings_exists:
        op.create_table(
            'reminder_settings',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('user_id', sa.Integer(), nullable=False),
            sa.Column('prayer_series_id', sa.Integer(), nullable=True),
            sa.Column('event_series_id', sa.Integer(), nullable=True),
            sa.Column('remind_before_minutes', sa.Integer(), nullable=False),
            sa.Column('is_enabled', sa.Boolean(), nullable=False, server_default='true'),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['prayer_series_id'], ['prayer_series.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['event_series_id'], ['event_series.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_reminder_settings_id'), 'reminder_settings', ['id'], unique=False)
        op.create_index(op.f('ix_reminder_settings_user_id'), 'reminder_settings', ['user_id'], unique=False)
        op.create_index(op.f('ix_reminder_settings_prayer_series_id'), 'reminder_settings', ['prayer_series_id'], unique=False)
        op.create_index(op.f('ix_reminder_settings_event_series_id'), 'reminder_settings', ['event_series_id'], unique=False)
        op.create_index('ix_reminder_user_prayer', 'reminder_settings', ['user_id', 'prayer_series_id', 'remind_before_minutes'], unique=True)
        op.create_index('ix_reminder_user_event', 'reminder_settings', ['user_id', 'event_series_id', 'remind_before_minutes'], unique=True)

    # Create prayer_requests table
    if not prayer_requests_exists:
        op.create_table(
            'prayer_requests',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('user_id', sa.Integer(), nullable=True),
            sa.Column('request_text', sa.String(), nullable=False),
            sa.Column('is_anonymous', sa.Boolean(), nullable=False, server_default='false'),
            sa.Column('status', sa.String(), nullable=False, server_default='new'),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_prayer_requests_id'), 'prayer_requests', ['id'], unique=False)
        op.create_index(op.f('ix_prayer_requests_user_id'), 'prayer_requests', ['user_id'], unique=False)
        op.create_index(op.f('ix_prayer_requests_status'), 'prayer_requests', ['status'], unique=False)
        op.create_index(op.f('ix_prayer_requests_created_at'), 'prayer_requests', ['created_at'], unique=False)


def downgrade() -> None:
    # Drop prayer_requests table
    op.drop_index(op.f('ix_prayer_requests_created_at'), table_name='prayer_requests')
    op.drop_index(op.f('ix_prayer_requests_status'), table_name='prayer_requests')
    op.drop_index(op.f('ix_prayer_requests_user_id'), table_name='prayer_requests')
    op.drop_index(op.f('ix_prayer_requests_id'), table_name='prayer_requests')
    op.drop_table('prayer_requests')

    # Drop reminder_settings table
    op.drop_index('ix_reminder_user_event', table_name='reminder_settings')
    op.drop_index('ix_reminder_user_prayer', table_name='reminder_settings')
    op.drop_index(op.f('ix_reminder_settings_event_series_id'), table_name='reminder_settings')
    op.drop_index(op.f('ix_reminder_settings_prayer_series_id'), table_name='reminder_settings')
    op.drop_index(op.f('ix_reminder_settings_user_id'), table_name='reminder_settings')
    op.drop_index(op.f('ix_reminder_settings_id'), table_name='reminder_settings')
    op.drop_table('reminder_settings')

    # Drop favorites table
    op.drop_index('ix_favorites_user_event', table_name='favorites')
    op.drop_index('ix_favorites_user_prayer', table_name='favorites')
    op.drop_index(op.f('ix_favorites_event_series_id'), table_name='favorites')
    op.drop_index(op.f('ix_favorites_prayer_series_id'), table_name='favorites')
    op.drop_index(op.f('ix_favorites_user_id'), table_name='favorites')
    op.drop_index(op.f('ix_favorites_id'), table_name='favorites')
    op.drop_table('favorites')

    # Drop attendance table
    op.drop_index('ix_attendance_user_event', table_name='attendance')
    op.drop_index('ix_attendance_user_prayer', table_name='attendance')
    op.drop_index(op.f('ix_attendance_joined_at'), table_name='attendance')
    op.drop_index(op.f('ix_attendance_event_occurrence_id'), table_name='attendance')
    op.drop_index(op.f('ix_attendance_prayer_occurrence_id'), table_name='attendance')
    op.drop_index(op.f('ix_attendance_user_id'), table_name='attendance')
    op.drop_index(op.f('ix_attendance_id'), table_name='attendance')
    op.drop_table('attendance')
