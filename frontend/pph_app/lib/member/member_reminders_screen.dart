import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/engagement_service.dart';
import '../services/prayer_service.dart';
import '../services/event_service.dart';
import '../services/notification_service.dart';
import 'member_prayer_details_screen.dart';
import 'member_event_details_screen.dart';

class MemberRemindersScreen extends StatefulWidget {
  const MemberRemindersScreen({super.key});

  @override
  State<MemberRemindersScreen> createState() => _MemberRemindersScreenState();
}

class _MemberRemindersScreenState extends State<MemberRemindersScreen> {
  List<Map<String, dynamic>> _allReminders = [];
  List<Map<String, dynamic>> _prayerReminders = [];
  List<Map<String, dynamic>> _eventReminders = [];
  bool _loading = true;
  Map<int, Map<String, dynamic>> _prayerSeriesMap = {};
  Map<int, Map<String, dynamic>> _eventSeriesMap = {};

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _loading = true);

    try {
      // Load all reminders
      final reminders = await EngagementService.getReminders();
      
      // Separate prayer and event reminders
      final prayerReminders = reminders.where((r) => r['prayer_series_id'] != null).toList();
      final eventReminders = reminders.where((r) => r['event_series_id'] != null).toList();

      // Get unique series IDs
      final prayerSeriesIds = prayerReminders.map((r) => r['prayer_series_id'] as int).toSet().toList();
      final eventSeriesIds = eventReminders.map((r) => r['event_series_id'] as int).toSet().toList();

      final now = DateTime.now();

      // Load prayer occurrences to get NEXT upcoming occurrence for each series
      if (prayerSeriesIds.isNotEmpty) {
        final allPrayerOccurrences = await PrayerService.getPrayerOccurrences();
        for (final occurrence in allPrayerOccurrences) {
          final seriesId = occurrence['prayer_series_id'] as int?;
          if (seriesId != null && prayerSeriesIds.contains(seriesId)) {
            final startStr = occurrence['start_datetime'] as String?;
            if (startStr != null) {
              try {
                final startTime = DateTime.parse(startStr).toLocal();
                // Only consider future occurrences
                if (startTime.isAfter(now)) {
                  if (!_prayerSeriesMap.containsKey(seriesId)) {
                    _prayerSeriesMap[seriesId] = occurrence;
                  } else {
                    // Keep the earliest upcoming occurrence
                    final existing = _prayerSeriesMap[seriesId]!;
                    final existingStart = existing['start_datetime'] as String?;
                    if (existingStart != null) {
                      try {
                        final existingTime = DateTime.parse(existingStart).toLocal();
                        if (startTime.isBefore(existingTime)) {
                          _prayerSeriesMap[seriesId] = occurrence;
                        }
                      } catch (e) {
                        // Keep existing if parsing fails
                      }
                    }
                  }
                }
              } catch (e) {
                // Skip if parsing fails
              }
            }
          }
        }
      }

      // Load event occurrences to get NEXT upcoming occurrence for each series
      if (eventSeriesIds.isNotEmpty) {
        final allEventOccurrences = await EventService.getEventOccurrences();
        for (final occurrence in allEventOccurrences) {
          final seriesId = occurrence['event_series_id'] as int?;
          if (seriesId != null && eventSeriesIds.contains(seriesId)) {
            final startStr = occurrence['start_datetime'] as String?;
            if (startStr != null) {
              try {
                final startTime = DateTime.parse(startStr).toLocal();
                // Only consider future occurrences
                if (startTime.isAfter(now)) {
                  if (!_eventSeriesMap.containsKey(seriesId)) {
                    _eventSeriesMap[seriesId] = occurrence;
                  } else {
                    // Keep the earliest upcoming occurrence
                    final existing = _eventSeriesMap[seriesId]!;
                    final existingStart = existing['start_datetime'] as String?;
                    if (existingStart != null) {
                      try {
                        final existingTime = DateTime.parse(existingStart).toLocal();
                        if (startTime.isBefore(existingTime)) {
                          _eventSeriesMap[seriesId] = occurrence;
                        }
                      } catch (e) {
                        // Keep existing if parsing fails
                      }
                    }
                  }
                }
              } catch (e) {
                // Skip if parsing fails
              }
            }
          }
        }
      }

      // Group reminders by series and attach occurrence data
      final prayerRemindersWithData = <Map<String, dynamic>>[];
      for (final reminder in prayerReminders) {
        final seriesId = reminder['prayer_series_id'] as int;
        final occurrence = _prayerSeriesMap[seriesId];
        if (occurrence != null) {
          prayerRemindersWithData.add({
            ...reminder,
            'occurrence': occurrence,
            'title': occurrence['title'] as String? ?? 'Prayer',
            'start_datetime': occurrence['start_datetime'] as String?,
          });
        }
      }

      final eventRemindersWithData = <Map<String, dynamic>>[];
      for (final reminder in eventReminders) {
        final seriesId = reminder['event_series_id'] as int;
        final occurrence = _eventSeriesMap[seriesId];
        if (occurrence != null) {
          eventRemindersWithData.add({
            ...reminder,
            'occurrence': occurrence,
            'title': occurrence['title'] as String? ?? 'Event',
            'start_datetime': occurrence['start_datetime'] as String?,
          });
        }
      }

      // Sort by next occurrence time (earliest first)
      prayerRemindersWithData.sort((a, b) {
        final aStart = a['start_datetime'] as String?;
        final bStart = b['start_datetime'] as String?;
        if (aStart == null) return 1;
        if (bStart == null) return -1;
        try {
          final aTime = DateTime.parse(aStart).toLocal();
          final bTime = DateTime.parse(bStart).toLocal();
          return aTime.compareTo(bTime);
        } catch (e) {
          return 0;
        }
      });

      eventRemindersWithData.sort((a, b) {
        final aStart = a['start_datetime'] as String?;
        final bStart = b['start_datetime'] as String?;
        if (aStart == null) return 1;
        if (bStart == null) return -1;
        try {
          final aTime = DateTime.parse(aStart).toLocal();
          final bTime = DateTime.parse(bStart).toLocal();
          return aTime.compareTo(bTime);
        } catch (e) {
          return 0;
        }
      });

      // Filter to show only enabled reminders
      final enabledPrayerReminders = prayerRemindersWithData.where(
        (r) => r['is_enabled'] == true
      ).toList();
      
      final enabledEventReminders = eventRemindersWithData.where(
        (r) => r['is_enabled'] == true
      ).toList();

      if (mounted) {
        setState(() {
          _allReminders = reminders;
          _prayerReminders = enabledPrayerReminders;
          _eventReminders = enabledEventReminders;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load reminders: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _canRemind(String? startStr, int minutesBefore) {
    if (startStr == null) return false;
    
    try {
      final startTime = DateTime.parse(startStr).toLocal();
      final reminderTime = startTime.subtract(Duration(minutes: minutesBefore));
      return reminderTime.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  Future<void> _toggleReminder(Map<String, dynamic> reminder, bool currentValue) async {
    final reminderId = reminder['id'] as int?;
    if (reminderId == null) return;

    final minutesBefore = reminder['remind_before_minutes'] as int? ?? 0;
    final startStr = reminder['start_datetime'] as String?;
    
    // Check if reminder time is in the past
    if (!currentValue && startStr != null && !_canRemind(startStr, minutesBefore)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Cannot enable reminder: The ${minutesBefore}-minute reminder time has already passed"),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Optimistically remove from list if disabling (since we only show enabled reminders)
    if (currentValue) {
      setState(() {
        if (reminder['prayer_series_id'] != null) {
          _prayerReminders.removeWhere((r) => r['id'] == reminderId);
        } else if (reminder['event_series_id'] != null) {
          _eventReminders.removeWhere((r) => r['id'] == reminderId);
        }
      });
    }

    try {
      final success = await EngagementService.updateReminder(reminderId, !currentValue);
      
      if (success) {
        // Schedule or cancel notification
        final occurrence = reminder['occurrence'] as Map<String, dynamic>?;
        if (occurrence != null && startStr != null) {
          try {
            final startTime = DateTime.parse(startStr).toLocal();
            final title = reminder['title'] as String? ?? 'Reminder';
            final prayerSeriesId = reminder['prayer_series_id'] as int?;
            final eventSeriesId = reminder['event_series_id'] as int?;
            
            if (prayerSeriesId != null) {
              final notificationId = NotificationService.getPrayerReminderId(prayerSeriesId, minutesBefore);
              if (!currentValue) {
                await NotificationService().schedulePrayerReminder(
                  reminderId: notificationId,
                  prayerTitle: title,
                  prayerStartTime: startTime,
                  minutesBefore: minutesBefore,
                );
              } else {
                await NotificationService().cancelReminder(notificationId);
              }
            } else if (eventSeriesId != null) {
              final notificationId = NotificationService.getEventReminderId(eventSeriesId, minutesBefore);
              if (!currentValue) {
                await NotificationService().scheduleEventReminder(
                  reminderId: notificationId,
                  eventTitle: title,
                  eventStartTime: startTime,
                  minutesBefore: minutesBefore,
                );
              } else {
                await NotificationService().cancelReminder(notificationId);
              }
            }
          } catch (e) {
            print("Failed to schedule/cancel notification: $e");
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                !currentValue 
                  ? "Reminder enabled for ${minutesBefore} minutes before" 
                  : "Reminder disabled",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // Reload to sync with backend (especially if enabling, to add it back with full data)
        _loadReminders();
      } else {
        // Revert on failure - reload to restore the list
        _loadReminders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to update reminder"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Revert on error - reload to restore the list
      _loadReminders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.inDays > 7) {
      return DateFormat('MMM d, y').format(dateTime);
    } else if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Tomorrow';
      }
      return 'In ${difference.inDays} days';
    } else if (difference.inHours > 0) {
      return 'In ${difference.inHours} hour${difference.inHours == 1 ? '' : 's'}';
    } else if (difference.inMinutes > 0) {
      return 'In ${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'}';
    } else if (difference.inMinutes == 0 && difference.inSeconds > 0) {
      return 'In a few seconds';
    } else {
      return 'Now';
    }
  }

  Widget _buildReminderCard(Map<String, dynamic> reminder) {
    final title = reminder['title'] as String? ?? 'Reminder';
    final startStr = reminder['start_datetime'] as String?;
    final minutesBefore = reminder['remind_before_minutes'] as int? ?? 0;
    final isEnabled = reminder['is_enabled'] as bool? ?? false;
    final prayerSeriesId = reminder['prayer_series_id'] as int?;
    final eventSeriesId = reminder['event_series_id'] as int?;
    final occurrence = reminder['occurrence'] as Map<String, dynamic>?;

    DateTime? startTime;
    DateTime? reminderTime;
    String timeDisplay = "TBD";
    String reminderTimeDisplay = "";
    String relativeTime = "";

    if (startStr != null) {
      try {
        startTime = DateTime.parse(startStr).toLocal();
        reminderTime = startTime.subtract(Duration(minutes: minutesBefore));
        timeDisplay = DateFormat('MMM d, y • h:mm a').format(startTime);
        reminderTimeDisplay = DateFormat('h:mm a').format(reminderTime);
        relativeTime = _getRelativeTime(startTime);
      } catch (e) {
        timeDisplay = startStr;
      }
    }

    final canRemind = startStr != null ? _canRemind(startStr, minutesBefore) : false;
    final isPast = startStr != null && !canRemind && !isEnabled;
    final isReminderPast = reminderTime != null && reminderTime.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isEnabled ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isEnabled 
            ? (prayerSeriesId != null ? Colors.blue[300]! : Colors.orange[300]!)
            : Colors.grey[300]!,
          width: isEnabled ? 1.5 : 0.5,
        ),
      ),
      child: InkWell(
        onTap: occurrence != null ? () {
          if (prayerSeriesId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MemberPrayerDetailsScreen(prayer: occurrence),
              ),
            );
          } else if (eventSeriesId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MemberEventDetailsScreen(event: occurrence),
              ),
            );
          }
        } : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (prayerSeriesId != null ? Colors.blue : Colors.orange)[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      prayerSeriesId != null ? Icons.access_time : Icons.event,
                      color: prayerSeriesId != null ? Colors.blue[700] : Colors.orange[700],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isEnabled)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Active',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[800],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (relativeTime.isNotEmpty)
                          Text(
                            relativeTime,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          timeDisplay,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications,
                      size: 16,
                      color: isEnabled ? Colors.blue[700] : Colors.grey[400],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Remind ${minutesBefore} minutes before",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isEnabled ? Colors.grey[800] : Colors.grey[500],
                            ),
                          ),
                          if (reminderTimeDisplay.isNotEmpty && isEnabled)
                            Text(
                              "Notification at $reminderTimeDisplay",
                              style: TextStyle(
                                fontSize: 11,
                                color: isReminderPast ? Colors.red[600] : Colors.grey[600],
                                fontStyle: isReminderPast ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isEnabled,
                      onChanged: (isPast && !isEnabled) ? null : (value) => _toggleReminder(reminder, isEnabled),
                      activeColor: Colors.blue[700],
                    ),
                  ],
                ),
              ),
              if (isPast && !isEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.orange[600]),
                      const SizedBox(width: 4),
                      Text(
                        "Reminder time has passed",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Reminders"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReminders,
              child: _prayerReminders.isEmpty && _eventReminders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No active reminders",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              "Enable reminders for prayers and events to get notified before they start",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary header
                          Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.notifications_active, color: Colors.blue[700], size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${_prayerReminders.length + _eventReminders.length} Active Reminder${(_prayerReminders.length + _eventReminders.length) == 1 ? '' : 's'}",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[900],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "You'll be notified before each event starts",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_prayerReminders.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time, color: Colors.blue[700], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Prayer Reminders (${_prayerReminders.length})",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ..._prayerReminders.map((r) => _buildReminderCard(r)),
                          ],
                          if (_eventReminders.isNotEmpty) ...[
                            Padding(
                              padding: EdgeInsets.fromLTRB(20, _prayerReminders.isNotEmpty ? 20 : 8, 20, 12),
                              child: Row(
                                children: [
                                  Icon(Icons.event, color: Colors.orange[700], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Event Reminders (${_eventReminders.length})",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ..._eventReminders.map((r) => _buildReminderCard(r)),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
      extendBody: true,
    );
  }
}
