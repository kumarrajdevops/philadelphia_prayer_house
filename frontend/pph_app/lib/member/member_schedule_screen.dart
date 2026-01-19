import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/prayer_service.dart';
import 'member_prayer_details_screen.dart';

class MemberScheduleScreen extends StatefulWidget {
  const MemberScheduleScreen({super.key});

  @override
  State<MemberScheduleScreen> createState() => _MemberScheduleScreenState();
}

class _MemberScheduleScreenState extends State<MemberScheduleScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _allPrayers = [];
  bool _loading = true;
  int _selectedTabIndex = 0;
  late TabController _tabController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _loadPrayers();
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
      _loadPrayers(); // Force refresh when app comes to foreground
    } else if (state == AppLifecycleState.paused) {
      _refreshTimer?.cancel(); // Stop timer when app goes to background
    } else if (state == AppLifecycleState.inactive) {
      _refreshTimer?.cancel();
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted && _selectedTabIndex == 0) { // Only auto-refresh Today tab
        _loadPrayers(silent: true);
      }
    });
  }

  Future<void> _loadPrayers({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }

    try {
      // Use occurrences API (loads all occurrences, we filter by tab client-side)
      final prayers = await PrayerService.getPrayerOccurrences();
      if (mounted) {
        setState(() {
          _allPrayers = prayers;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to load prayers: ${e.toString()}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> _getTodayPrayers() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    return _allPrayers.where((prayer) {
      final startStr = prayer['start_datetime'] as String?;
      final endStr = prayer['end_datetime'] as String?;
      final status = (prayer['status'] as String? ?? 'upcoming').toLowerCase();
      
      if (startStr == null || endStr == null) return false;
      
      // Exclude completed prayers from Today tab
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
        final timeA = a['start_datetime'] as String? ?? '';
        final timeB = b['start_datetime'] as String? ?? '';
        return timeA.compareTo(timeB);
      });
  }

  List<Map<String, dynamic>> _getUpcomingPrayers() {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    return _allPrayers.where((prayer) {
      final startStr = prayer['start_datetime'] as String?;
      final status = (prayer['status'] as String? ?? 'upcoming').toLowerCase();
      
      if (startStr == null) return false;
      
      try {
        final start = DateTime.parse(startStr).toLocal();
        // Show future prayers that start after today (tomorrow or later)
        // Exclude today's prayers (they should be in Today tab)
        return start.isAfter(todayEnd) && status != 'completed';
      } catch (e) {
        return false;
      }
    }).toList()
      ..sort((a, b) {
        final timeA = a['start_datetime'] as String? ?? '';
        final timeB = b['start_datetime'] as String? ?? '';
        return timeA.compareTo(timeB);
      });
  }

  List<Map<String, dynamic>> _getOngoingPrayers() {
    return _allPrayers.where((prayer) {
      final status = (prayer['status'] as String? ?? '').toLowerCase();
      return status == 'ongoing';
    }).toList()
      ..sort((a, b) {
        final startA = a['start_datetime'] as String? ?? '';
        final startB = b['start_datetime'] as String? ?? '';
        return startA.compareTo(startB);
      });
  }

  List<Map<String, dynamic>> _getPastPrayers() {
    final now = DateTime.now();
    
    return _allPrayers.where((prayer) {
      final endStr = prayer['end_datetime'] as String?;
      final status = (prayer['status'] as String? ?? 'upcoming').toLowerCase();
      
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
        final timeA = a['start_datetime'] as String? ?? '';
        final timeB = b['start_datetime'] as String? ?? '';
        return timeB.compareTo(timeA); // Reverse order for past
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
          boxShadow: [
            BoxShadow(
              color: Colors.red.withAlpha((255 * 0.2).round()),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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

  Widget _buildPrayerCard(Map<String, dynamic> prayer) {
    final title = prayer['title'] as String? ?? 'Prayer';
    final startStr = prayer['start_datetime'] as String?;
    final endStr = prayer['end_datetime'] as String?;
    final status = (prayer['status'] as String? ?? '').toLowerCase();
    final prayerType = (prayer['prayer_type'] as String? ?? 'offline').toLowerCase();
    final location = prayer['location'] as String?;
    final recurrenceType = prayer['recurrence_type'] as String?;
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
              builder: (_) => MemberPrayerDetailsScreen(prayer: prayer),
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
                  Icons.favorite,
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
                        // Prayer Type Badge
                        if (prayerType == 'online')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green[300]!, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat, size: 12, color: Colors.green[700]),
                                const SizedBox(width: 4),
                                Text(
                                  'Online',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange[300]!, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on, size: 12, color: Colors.orange[700]),
                                const SizedBox(width: 4),
                                Text(
                                  'Offline',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange[700],
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
    final ongoingPrayers = _getOngoingPrayers();
    
    if (ongoingPrayers.isEmpty) {
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
        ...ongoingPrayers.map((prayer) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildPrayerCard(prayer),
        )),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTodayTab() {
    final todayPrayers = _getTodayPrayers();
    final ongoingPrayers = _getOngoingPrayers();

    if (todayPrayers.isEmpty && ongoingPrayers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No prayers for today",
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

    return RefreshIndicator(
      onRefresh: _loadPrayers,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (ongoingPrayers.isNotEmpty) _buildLIVENowSection(),
          ...todayPrayers.where((p) {
            final status = (p['status'] as String? ?? '').toLowerCase();
            return status != 'ongoing'; // Don't duplicate ongoing prayers
          }).map((prayer) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildPrayerCard(prayer),
          )),
        ],
      ),
    );
  }

  Widget _buildUpcomingTab() {
    final upcomingPrayers = _getUpcomingPrayers();

    if (upcomingPrayers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No upcoming prayers",
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

    return RefreshIndicator(
      onRefresh: _loadPrayers,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: upcomingPrayers.map((prayer) => _buildPrayerCard(prayer)).toList(),
      ),
    );
  }

  Widget _buildPastTab() {
    final pastPrayers = _getPastPrayers();

    if (pastPrayers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No past prayers",
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

    return RefreshIndicator(
      onRefresh: _loadPrayers,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: pastPrayers.map((prayer) => _buildPrayerCard(prayer)).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Prayer Schedule"),
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
            if (index == 0) {
              _startAutoRefresh(); // Restart auto-refresh for Today tab
            } else {
              _refreshTimer?.cancel(); // Stop auto-refresh for other tabs
            }
            // Refresh when switching tabs
            _loadPrayers(silent: true);
          },
          tabs: const [
            Tab(text: "Today"),
            Tab(text: "Upcoming"),
            Tab(text: "Past"),
          ],
        ),
      ),
      body: _loading && _allPrayers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
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
      extendBody: true,
    );
  }
}

