import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/engagement_service.dart';
import '../services/notification_service.dart';

class MemberEventDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const MemberEventDetailsScreen({
    super.key,
    required this.event,
  });

  @override
  State<MemberEventDetailsScreen> createState() => _MemberEventDetailsScreenState();
}

class _MemberEventDetailsScreenState extends State<MemberEventDetailsScreen> {
  bool _reminder15Min = false;
  bool _reminder5Min = false;
  bool _isLoadingReminders = false;
  int? _reminder15Id;
  int? _reminder5Id;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final eventSeriesId = widget.event['event_series_id'] as int?;
    if (eventSeriesId == null) return;

    try {
      final reminders = await EngagementService.getReminders();
      final eventReminders = reminders.where(
        (r) => r['event_series_id'] == eventSeriesId,
      ).toList();

      if (mounted) {
        setState(() {
          // Reset state first
          _reminder15Min = false;
          _reminder15Id = null;
          _reminder5Min = false;
          _reminder5Id = null;
          
          // Then set state from API response
          for (final reminder in eventReminders) {
            if (reminder['remind_before_minutes'] == 15) {
              _reminder15Min = reminder['is_enabled'] as bool? ?? false;
              _reminder15Id = reminder['id'] as int?;
            } else if (reminder['remind_before_minutes'] == 5) {
              _reminder5Min = reminder['is_enabled'] as bool? ?? false;
              _reminder5Id = reminder['id'] as int?;
            }
          }
        });
      }

      // Schedule notifications for enabled reminders
      final startStr = widget.event['start_datetime'] as String?;
      if (startStr != null) {
        try {
          final eventStartTime = DateTime.parse(startStr).toLocal();
          final eventTitle = widget.event['title'] as String? ?? 'Event';
          
          for (final reminder in eventReminders) {
            if (reminder['is_enabled'] == true) {
              final minutesBefore = reminder['remind_before_minutes'] as int? ?? 0;
              final notificationId = NotificationService.getEventReminderId(eventSeriesId!, minutesBefore);
              
              await NotificationService().scheduleEventReminder(
                reminderId: notificationId,
                eventTitle: eventTitle,
                eventStartTime: eventStartTime,
                minutesBefore: minutesBefore,
              );
            }
          }
        } catch (e) {
          print("Failed to schedule reminders: $e");
        }
      }
    } catch (e) {
      print("Failed to load reminders: $e");
    }
  }

  bool _canRemind(int minutesBefore) {
    final startStr = widget.event['start_datetime'] as String?;
    if (startStr == null) return false;
    
    try {
      final eventStartTime = DateTime.parse(startStr).toLocal();
      final reminderTime = eventStartTime.subtract(Duration(minutes: minutesBefore));
      return reminderTime.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  Future<void> _toggleReminder(int minutes, bool currentValue) async {
    final eventSeriesId = widget.event['event_series_id'] as int?;
    if (eventSeriesId == null || _isLoadingReminders) return;

    final newValue = !currentValue;
    
    // Only prevent enabling if the reminder time is in the past
    // Allow disabling even if time has passed
    if (newValue && !_canRemind(minutes)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Cannot set reminder: The ${minutes}-minute reminder time has already passed",
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Update state optimistically for immediate UI feedback
    setState(() {
      _isLoadingReminders = true;
      if (minutes == 15) {
        _reminder15Min = newValue;
      } else if (minutes == 5) {
        _reminder5Min = newValue;
      }
    });

    try {
      final startStr = widget.event['start_datetime'] as String?;
      final eventTitle = widget.event['title'] as String? ?? 'Event';
      final notificationId = NotificationService.getEventReminderId(eventSeriesId, minutes);

      if (minutes == 15) {
        if (_reminder15Id != null) {
          // Update existing reminder
          final success = await EngagementService.updateReminder(_reminder15Id!, newValue);
          if (!success && mounted) {
            // Revert state if update failed
            setState(() => _reminder15Min = currentValue);
            throw Exception("Failed to update reminder");
          }
        } else {
          // Create new reminder
          final result = await EngagementService.setReminder(
            eventSeriesId: eventSeriesId,
            remindBeforeMinutes: 15,
            isEnabled: newValue,
          );
          if (result == null && mounted) {
            // Revert state if creation failed
            setState(() => _reminder15Min = currentValue);
            throw Exception("Failed to create reminder");
          }
          if (result != null && mounted) {
            setState(() => _reminder15Id = result['id'] as int?);
          }
        }
      } else if (minutes == 5) {
        if (_reminder5Id != null) {
          // Update existing reminder
          final success = await EngagementService.updateReminder(_reminder5Id!, newValue);
          if (!success && mounted) {
            // Revert state if update failed
            setState(() => _reminder5Min = currentValue);
            throw Exception("Failed to update reminder");
          }
        } else {
          // Create new reminder
          final result = await EngagementService.setReminder(
            eventSeriesId: eventSeriesId,
            remindBeforeMinutes: 5,
            isEnabled: newValue,
          );
          if (result == null && mounted) {
            // Revert state if creation failed
            setState(() => _reminder5Min = currentValue);
            throw Exception("Failed to create reminder");
          }
          if (result != null && mounted) {
            setState(() => _reminder5Id = result['id'] as int?);
          }
        }
      }

      // Schedule or cancel notification
      if (startStr != null) {
        try {
          final eventStartTime = DateTime.parse(startStr).toLocal();
          
          if (newValue) {
            // Schedule notification
            await NotificationService().scheduleEventReminder(
              reminderId: notificationId,
              eventTitle: eventTitle,
              eventStartTime: eventStartTime,
              minutesBefore: minutes,
            );
          } else {
            // Cancel notification
            await NotificationService().cancelReminder(notificationId);
          }
        } catch (e) {
          print("Failed to schedule/cancel notification: $e");
        }
      }

      // Reload reminders to sync state with backend
      await _loadReminders();
      
      if (mounted) {
        setState(() {
          _isLoadingReminders = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue 
                ? "Reminder set for $minutes minutes before" 
                : "Reminder disabled",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Revert state on error
      if (mounted) {
        setState(() {
          _isLoadingReminders = false;
          if (minutes == 15) {
            _reminder15Min = currentValue; // Revert to previous value
          } else if (minutes == 5) {
            _reminder5Min = currentValue; // Revert to previous value
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update reminder: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted && !_isLoadingReminders) {
        setState(() => _isLoadingReminders = false);
      }
    }
  }

  String _formatDate(String? startStr) {
    if (startStr == null || startStr.isEmpty) return "TBD";
    try {
      final dt = DateTime.parse(startStr).toLocal();
      return DateFormat('EEEE, MMMM d, y').format(dt);
    } catch (e) {
      return startStr;
    }
  }

  String _formatTime(String? startStr, String? endStr) {
    if (startStr == null || endStr == null) return "TBD";
    try {
      final start = DateTime.parse(startStr).toLocal();
      final end = DateTime.parse(endStr).toLocal();
      
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        // Same day
        return "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}";
      } else {
        // Multi-day
        return "${DateFormat('MMM d, h:mm a').format(start)} - ${DateFormat('MMM d, h:mm a').format(end)}";
      }
    } catch (e) {
      return "$startStr - $endStr";
    }
  }

  Widget _buildStatusTag(String status) {
    String displayText;
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'ongoing':
        displayText = 'LIVE NOW';
        backgroundColor = Colors.red[50]!;
        textColor = Colors.red[700]!;
        break;
      case 'completed':
        displayText = 'COMPLETED';
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
        break;
      case 'upcoming':
      default:
        displayText = 'UPCOMING';
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue[700]!;
        break;
    }

    if (status.toLowerCase() == 'ongoing') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[600]!, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: Colors.red[700]!,
                shape: BoxShape.circle,
              ),
            ),
            Text(
              displayText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textColor,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withAlpha((255 * 0.3).round()), width: 1),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: valueColor ?? Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGoogleMaps(BuildContext context, String location) async {
    try {
      final encodedLocation = Uri.encodeComponent(location);
      final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedLocation');
      
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not open Google Maps"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error opening Google Maps: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  String _computeStatus(String? startStr, String? endStr) {
    if (startStr == null || endStr == null) {
      return 'upcoming';
    }
    
    try {
      final now = DateTime.now().toUtc();
      final start = DateTime.parse(startStr).toUtc();
      final end = DateTime.parse(endStr).toUtc();
      
      if (now.isBefore(start)) {
        return 'upcoming';
      } else if (now.isBefore(end)) {
        return 'ongoing';
      } else {
        return 'completed';
      }
    } catch (e) {
      // Fallback to status from event object if parsing fails
      return (widget.event['status'] as String? ?? 'upcoming').toLowerCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.event['title'] as String? ?? 'Event';
    final description = widget.event['description'] as String?;
    final startStr = widget.event['start_datetime'] as String?;
    final endStr = widget.event['end_datetime'] as String?;
    // Compute status dynamically based on current time
    final status = _computeStatus(startStr, endStr);
    final location = widget.event['location'] as String?;
    final recurrenceType = widget.event['recurrence_type'] as String?;
    final eventSeriesId = widget.event['event_series_id'] as int?;
    final isOngoing = status == 'ongoing';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Event Details"),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isOngoing ? Colors.red[50] : Colors.purple[50],
                border: isOngoing
                    ? Border(
                        bottom: BorderSide(color: Colors.red[400]!, width: 2),
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStatusTag(status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Event Badge (similar to Prayer Type badge in prayer details)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple[300]!, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event, size: 16, color: Colors.purple[700]),
                            const SizedBox(width: 6),
                            Text(
                              'Event',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (recurrenceType != null && recurrenceType.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            recurrenceType,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Details Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date
                  _buildInfoRow(
                    Icons.calendar_today,
                    "Date",
                    _formatDate(startStr),
                  ),
                  const Divider(),

                  // Time
                  _buildInfoRow(
                    Icons.access_time,
                    "Time",
                    _formatTime(startStr, endStr),
                  ),
                  const Divider(),

                  // Description
                  if (description != null && description.isNotEmpty) ...[
                    _buildInfoRow(
                      Icons.description,
                      "Description",
                      description,
                    ),
                    const Divider(),
                  ],

                  // Location
                  _buildInfoRow(
                    Icons.location_on,
                    "Location",
                    location ?? "Location TBD",
                  ),
                  const Divider(),
                  
                  // Reminders Section
                  if (eventSeriesId != null && status != 'completed') ...[
                    Row(
                      children: [
                        Icon(Icons.notifications, size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 12),
                        Text(
                          "Reminders",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 15 Minute Reminder
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 20, color: Colors.grey[700]),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "15 minutes before",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: _canRemind(15) ? Colors.grey[800] : Colors.grey[400],
                                    ),
                                  ),
                                  Text(
                                    _canRemind(15)
                                        ? "Get notified 15 minutes before event starts"
                                        : "Reminder time has passed",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _canRemind(15) ? Colors.grey[600] : Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: _reminder15Min,
                            onChanged: _isLoadingReminders
                                ? null
                                : (value) => _toggleReminder(15, _reminder15Min),
                            activeColor: Colors.blue[700],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 5 Minute Reminder
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 20, color: Colors.grey[700]),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "5 minutes before",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: _canRemind(5) ? Colors.grey[800] : Colors.grey[400],
                                    ),
                                  ),
                                  Text(
                                    _canRemind(5)
                                        ? "Get notified 5 minutes before event starts"
                                        : "Reminder time has passed",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _canRemind(5) ? Colors.grey[600] : Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: _reminder5Min,
                            onChanged: _isLoadingReminders
                                ? null
                                : (value) => _toggleReminder(5, _reminder5Min),
                            activeColor: Colors.blue[700],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: (isOngoing || status == 'upcoming') &&
              location != null && location.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton.icon(
                  onPressed: () => _openGoogleMaps(context, location),
                  icon: const Icon(Icons.map),
                  label: const Text("Open in Google Maps"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

