"""
Utility functions for event status computation and occurrence generation.
Status is computed dynamically based on current time vs event datetime range.
"""
from datetime import datetime, date, time, timedelta
from typing import List, Optional, Tuple
import calendar


def compute_event_status(start_datetime: datetime, end_datetime: datetime, now: datetime = None) -> str:
    """
    Compute event status based on current time vs event datetime range.
    
    Returns:
        - 'upcoming': now < start_datetime
        - 'ongoing': start_datetime ≤ now < end_datetime
        - 'completed': now ≥ end_datetime
    
    Args:
        start_datetime: Event start datetime (timezone-aware)
        end_datetime: Event end datetime (timezone-aware)
        now: Current datetime (defaults to datetime.now() if not provided)
    
    Returns:
        Status string: 'upcoming', 'ongoing', or 'completed'
    """
    if now is None:
        now = datetime.now(start_datetime.tzinfo) if start_datetime.tzinfo else datetime.now()
    
    # Ensure timezone-aware comparison
    if start_datetime.tzinfo is None:
        # Assume local timezone if not specified
        start_datetime = start_datetime.replace(tzinfo=now.tzinfo)
    if end_datetime.tzinfo is None:
        end_datetime = end_datetime.replace(tzinfo=now.tzinfo)
    if now.tzinfo is None:
        now = now.replace(tzinfo=start_datetime.tzinfo)
    
    # Truncate to minute precision
    now_truncated = datetime(
        now.year, now.month, now.day, now.hour, now.minute,
        tzinfo=now.tzinfo
    )
    start_truncated = datetime(
        start_datetime.year, start_datetime.month, start_datetime.day,
        start_datetime.hour, start_datetime.minute,
        tzinfo=start_datetime.tzinfo
    )
    end_truncated = datetime(
        end_datetime.year, end_datetime.month, end_datetime.day,
        end_datetime.hour, end_datetime.minute,
        tzinfo=end_datetime.tzinfo
    )
    
    # Determine status based on time comparison
    if now_truncated < start_truncated:
        return 'upcoming'
    elif start_truncated <= now_truncated < end_truncated:
        return 'ongoing'
    else:  # now_truncated >= end_truncated
        return 'completed'


def parse_recurrence_days(days_str: Optional[str]) -> List[int]:
    """
    Parse recurrence_days string (comma-separated) into list of integers.
    Example: "0,4" -> [0, 4] (Monday, Friday)
    
    Args:
        days_str: Comma-separated string of day numbers (0=Monday, 6=Sunday)
    
    Returns:
        List of integers representing weekdays
    """
    if not days_str:
        return []
    return [int(d.strip()) for d in days_str.split(',') if d.strip().isdigit()]


def generate_occurrences(
    start_datetime: datetime,
    end_datetime: datetime,
    recurrence_type: str,
    recurrence_days: Optional[str] = None,
    recurrence_end_date: Optional[date] = None,
    recurrence_count: Optional[int] = None,
    max_months: int = 3
) -> List[Tuple[datetime, datetime]]:
    """
    Generate event occurrences for the next 3 months (or until end condition).
    
    Args:
        start_datetime: First occurrence start datetime
        end_datetime: First occurrence end datetime
        recurrence_type: 'none', 'daily', 'weekly', 'monthly'
        recurrence_days: For weekly: comma-separated days (0=Mon, 6=Sun)
        recurrence_end_date: Optional end date for recurrence
        recurrence_count: Optional: end after N occurrences
        max_months: Maximum months to generate (default: 3)
    
    Returns:
        List of (start_datetime, end_datetime) tuples for each occurrence
    """
    occurrences = []
    
    # Calculate duration of the event
    duration = end_datetime - start_datetime
    
    # Calculate end date for generation (3 months from start)
    generation_end_date = (start_datetime.date() + timedelta(days=max_months * 30))
    
    # Determine actual end date (whichever comes first)
    actual_end_date = generation_end_date
    if recurrence_end_date:
        actual_end_date = min(actual_end_date, recurrence_end_date)
    
    if recurrence_type == 'none':
        # Single event
        occurrences.append((start_datetime, end_datetime))
    
    elif recurrence_type == 'daily':
        current_date = start_datetime.date()
        current_start = start_datetime
        count = 0
        
        while current_date <= actual_end_date:
            if recurrence_count and count >= recurrence_count:
                break
            
            current_end = current_start + duration
            occurrences.append((current_start, current_end))
            
            current_date += timedelta(days=1)
            current_start = datetime.combine(current_date, current_start.time())
            if start_datetime.tzinfo:
                current_start = current_start.replace(tzinfo=start_datetime.tzinfo)
            count += 1
    
    elif recurrence_type == 'weekly':
        days = parse_recurrence_days(recurrence_days)
        if not days:
            # Default to same weekday as start
            days = [start_datetime.weekday()]
        
        current_date = start_datetime.date()
        count = 0
        
        while current_date <= actual_end_date:
            if recurrence_count and count >= recurrence_count:
                break
            
            # Check each day in the week
            week_start = current_date - timedelta(days=current_date.weekday())
            for day_offset in days:
                occurrence_date = week_start + timedelta(days=day_offset)
                
                if occurrence_date < start_datetime.date():
                    continue
                if occurrence_date > actual_end_date:
                    break
                if recurrence_count and count >= recurrence_count:
                    break
                
                occurrence_start = datetime.combine(occurrence_date, start_datetime.time())
                if start_datetime.tzinfo:
                    occurrence_start = occurrence_start.replace(tzinfo=start_datetime.tzinfo)
                occurrence_end = occurrence_start + duration
                
                occurrences.append((occurrence_start, occurrence_end))
                count += 1
            
            # Move to next week
            current_date += timedelta(days=7)
    
    elif recurrence_type == 'monthly':
        current_date = start_datetime.date()
        count = 0
        
        while current_date <= actual_end_date:
            if recurrence_count and count >= recurrence_count:
                break
            
            occurrence_start = datetime.combine(current_date, start_datetime.time())
            if start_datetime.tzinfo:
                occurrence_start = occurrence_start.replace(tzinfo=start_datetime.tzinfo)
            occurrence_end = occurrence_start + duration
            
            occurrences.append((occurrence_start, occurrence_end))
            count += 1
            
            # Move to next month (same day)
            if current_date.month == 12:
                current_date = current_date.replace(year=current_date.year + 1, month=1)
            else:
                # Handle month-end edge cases (e.g., Jan 31 -> Feb 28)
                try:
                    current_date = current_date.replace(month=current_date.month + 1)
                except ValueError:
                    # Day doesn't exist in next month, use last day of month
                    last_day = calendar.monthrange(current_date.year, current_date.month + 1)[1]
                    current_date = current_date.replace(month=current_date.month + 1, day=last_day)
    
    return occurrences


def get_recurrence_label(recurrence_type: Optional[str]) -> Optional[str]:
    """
    Get human-readable recurrence label.
    
    Args:
        recurrence_type: 'none', 'daily', 'weekly', 'monthly'
    
    Returns:
        Label string or None
    """
    if not recurrence_type or recurrence_type == 'none':
        return None
    
    labels = {
        'daily': 'Daily',
        'weekly': 'Weekly',
        'monthly': 'Monthly'
    }
    return labels.get(recurrence_type)

