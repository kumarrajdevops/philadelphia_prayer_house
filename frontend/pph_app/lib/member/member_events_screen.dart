import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/event_service.dart';
import 'member_event_details_screen.dart';

class MemberEventsScreen extends StatefulWidget {
  const MemberEventsScreen({super.key});

  @override
  State<MemberEventsScreen> createState() => _MemberEventsScreenState();
}

class _MemberEventsScreenState extends State<MemberEventsScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _allEvents = [];
  bool _loading = true;
  int _selectedTabIndex = 0;
  late TabController _tabController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _loadEvents();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadEvents();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _refreshTimer?.cancel();
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted && _selectedTabIndex == 0) {
        _loadEvents(silent: true);
      }
    });
  }

  Future<void> _loadEvents({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }

    try {
      final events = await EventService.getEventOccurrences();
      if (mounted) {
        setState(() {
          _allEvents = events;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to load events: ${e.toString()}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> _getOngoingEvents() {
    return _allEvents.where((event) {
      final status = (event['status'] as String? ?? '').toLowerCase();
      return status == 'ongoing';
    }).toList()
      ..sort((a, b) {
        final startA = a['start_datetime'] as String? ?? '';
        final startB = b['start_datetime'] as String? ?? '';
        return startA.compareTo(startB);
      });
  }

  List<Map<String, dynamic>> _getTodayEvents() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    return _allEvents.where((event) {
      final startStr = event['start_datetime'] as String?;
      final endStr = event['end_datetime'] as String?;
      final status = (event['status'] as String? ?? '').toLowerCase();
      
      if (startStr == null || endStr == null) return false;
      
      // Exclude completed events from Today tab
      if (status == 'completed') return false;
      
      try {
        final start = DateTime.parse(startStr).toLocal();
        final end = DateTime.parse(endStr).toLocal();
        
        // Show if ongoing OR starts today (but not completed)
        return (start.isBefore(todayEnd) && end.isAfter(todayStart)) ||
               (start.isAfter(todayStart) && start.isBefore(todayEnd));
      } catch (e) {
        return false;
      }
    }).toList()
      ..sort((a, b) {
        final startA = a['start_datetime'] as String? ?? '';
        final startB = b['start_datetime'] as String? ?? '';
        return startA.compareTo(startB);
      });
  }

  List<Map<String, dynamic>> _getUpcomingEvents() {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    return _allEvents.where((event) {
      final startStr = event['start_datetime'] as String?;
      final status = (event['status'] as String? ?? '').toLowerCase();
      
      if (startStr == null) return false;
      
      try {
        final start = DateTime.parse(startStr).toLocal();
        // Show future events that start after today (tomorrow or later)
        // Exclude today's events (they should be in Today tab)
        return start.isAfter(todayEnd) && status != 'completed';
      } catch (e) {
        return false;
      }
    }).toList()
      ..sort((a, b) {
        final startA = a['start_datetime'] as String? ?? '';
        final startB = b['start_datetime'] as String? ?? '';
        return startA.compareTo(startB);
      });
  }

  List<Map<String, dynamic>> _getPastEvents() {
    final now = DateTime.now();
    
    return _allEvents.where((event) {
      final startStr = event['start_datetime'] as String?;
      final endStr = event['end_datetime'] as String?;
      final status = (event['status'] as String? ?? '').toLowerCase();
      
      if (endStr == null) return false;
      
      try {
        final end = DateTime.parse(endStr).toLocal();
        // Show if end_datetime is in the past (regardless of status, as fallback)
        // OR if status is explicitly 'completed'
        return end.isBefore(now) || status == 'completed';
      } catch (e) {
        return false;
      }
    }).toList()
      ..sort((a, b) {
        final startA = a['start_datetime'] as String? ?? '';
        final startB = b['start_datetime'] as String? ?? '';
        return startB.compareTo(startA); // Reverse order for past
      });
  }

  String _formatDate(String? startStr, String? endStr) {
    if (startStr == null || endStr == null) return "TBD";
    try {
      final start = DateTime.parse(startStr).toLocal();
      final end = DateTime.parse(endStr).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        // Same day
        final dateOnly = DateTime(start.year, start.month, start.day);
        if (dateOnly == today) {
          return "Today";
        } else if (dateOnly == tomorrow) {
          return "Tomorrow";
        } else {
          return DateFormat('MMM d, y').format(start);
        }
      } else {
        // Multi-day
        return "${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, y').format(end)}";
      }
    } catch (e) {
      return "TBD";
    }
  }

  String _formatTime(String? startStr, String? endStr) {
    if (startStr == null || endStr == null) return "TBD";
    try {
      final start = DateTime.parse(startStr).toLocal();
      final end = DateTime.parse(endStr).toLocal();
      return "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}";
    } catch (e) {
      return "TBD";
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

  Widget _buildEventCard(Map<String, dynamic> event) {
    final title = event['title'] as String? ?? 'Event';
    final startStr = event['start_datetime'] as String?;
    final endStr = event['end_datetime'] as String?;
    final status = (event['status'] as String? ?? '').toLowerCase();
    final location = event['location'] as String?;
    final recurrenceType = event['recurrence_type'] as String?;
    final isOngoing = status == 'ongoing';

    // Determine icon color based on status
    Color iconColor;
    Color iconBgColor;
    DateTime? start;
    try {
      if (startStr != null) {
        start = DateTime.parse(startStr).toLocal();
      }
    } catch (e) {
      start = null;
    }
    
    if (status == 'ongoing') {
      // Live Now - Red
      iconColor = Colors.red[700]!;
      iconBgColor = Colors.red[50]!;
    } else if (status == 'completed') {
      // Past - Grey
      iconColor = Colors.grey[600]!;
      iconBgColor = Colors.grey[200]!;
    } else if (start != null) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final startOnly = DateTime(start.year, start.month, start.day);
      
      if (start.isBefore(todayEnd) && start.isAfter(todayStart) || 
          (startOnly == todayStart)) {
        // Today - Orange
        iconColor = Colors.orange[700]!;
        iconBgColor = Colors.orange[50]!;
      } else {
        // Upcoming - Green
        iconColor = Colors.green[700]!;
        iconBgColor = Colors.green[50]!;
      }
    } else {
      // Default - Green for upcoming
      iconColor = Colors.green[700]!;
      iconBgColor = Colors.green[50]!;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isOngoing ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOngoing
          ? BorderSide(color: Colors.red[400]!, width: 2)
          : BorderSide.none,
      ),
      color: isOngoing ? Colors.red[50]?.withAlpha((255 * 0.3).round()) : null,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MemberEventDetailsScreen(event: event),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: isOngoing
                    ? Border.all(color: Colors.red[300]!, width: 1.5)
                    : null,
                ),
                child: Icon(
                  Icons.event,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Event Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purple[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.purple[300]!, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event, size: 12, color: Colors.purple[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Event',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusTag(status),
                      ],
                    ),
                    if (recurrenceType != null && recurrenceType.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        recurrenceType,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatDate(startStr, endStr),
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatTime(startStr, endStr),
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLIVENowSection() {
    final ongoingEvents = _getOngoingEvents();
    
    if (ongoingEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: const Text(
            "LIVE NOW",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
              letterSpacing: 1.0,
            ),
          ),
        ),
        ...ongoingEvents.map((event) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildEventCard(event),
        )),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Events"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          onTap: (index) {
            setState(() {
              _selectedTabIndex = index;
            });
          },
          tabs: const [
            Tab(text: "Today"),
            Tab(text: "Upcoming"),
            Tab(text: "Past"),
          ],
        ),
      ),
      body: _loading && _allEvents.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEvents,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Today Tab
                  _buildTodayTab(),
                  // Upcoming Tab
                  _buildUpcomingTab(),
                  // Past Tab
                  _buildPastTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildTodayTab() {
    final todayEvents = _getTodayEvents();
    final ongoingEvents = _getOngoingEvents();

    if (todayEvents.isEmpty && ongoingEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No events for today",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (ongoingEvents.isNotEmpty) _buildLIVENowSection(),
        ...todayEvents.where((e) {
          final status = (e['status'] as String? ?? '').toLowerCase();
          return status != 'ongoing'; // Don't duplicate ongoing events
        }).map((event) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildEventCard(event),
        )),
      ],
    );
  }

  Widget _buildUpcomingTab() {
    final upcomingEvents = _getUpcomingEvents();

    if (upcomingEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No upcoming events",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: upcomingEvents.map((event) => _buildEventCard(event)).toList(),
    );
  }

  Widget _buildPastTab() {
    final pastEvents = _getPastEvents();

    if (pastEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No past events",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: pastEvents.map((event) => _buildEventCard(event)).toList(),
    );
  }
}

