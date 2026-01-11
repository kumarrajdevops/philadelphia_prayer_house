"""
Utility functions for prayer status computation.
Status is computed dynamically based on current time vs prayer timestamps (HH:MM precision).
"""
from datetime import datetime, date, time


def compute_prayer_status(prayer_date: date, start_time: time, end_time: time, now: datetime = None) -> str:
    """
    Compute prayer status based on current time vs prayer timestamps (HH:MM precision).
    
    Returns:
        - 'upcoming': current_time < start_time
        - 'inprogress': start_time ≤ current_time < end_time
        - 'completed': current_time ≥ end_time
    
    Args:
        prayer_date: Prayer date
        start_time: Prayer start time
        end_time: Prayer end time
        now: Current datetime (defaults to datetime.now() if not provided)
    
    Returns:
        Status string: 'upcoming', 'inprogress', or 'completed'
    """
    if now is None:
        now = datetime.now()
    
    # Truncate to minute precision (HH:MM)
    now_truncated = datetime(now.year, now.month, now.day, now.hour, now.minute)
    
    # Combine prayer date and start time
    start_datetime = datetime.combine(prayer_date, start_time)
    start_truncated = datetime(
        start_datetime.year, start_datetime.month, start_datetime.day,
        start_datetime.hour, start_datetime.minute
    )
    
    # Combine prayer date and end time
    end_datetime = datetime.combine(prayer_date, end_time)
    end_truncated = datetime(
        end_datetime.year, end_datetime.month, end_datetime.day,
        end_datetime.hour, end_datetime.minute
    )
    
    # Determine status based on time comparison
    if now_truncated < start_truncated:
        return 'upcoming'
    elif start_truncated <= now_truncated < end_truncated:
        return 'inprogress'
    else:  # now_truncated >= end_truncated
        return 'completed'

