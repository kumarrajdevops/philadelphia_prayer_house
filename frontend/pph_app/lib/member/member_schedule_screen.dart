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

class _MemberScheduleScreenState extends State<MemberScheduleScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _allPrayers = [];
  bool _loading = true;
  int _selectedTabIndex = 0;
  late TabController _tabController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: Navigator.of(context));
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
      final prayers = await PrayerService.getAllPrayers();
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
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    return _allPrayers.where((prayer) {
      final prayerDate = prayer['prayer_date'] as String?;
      if (prayerDate != todayStr) return false;
      
      final status = (prayer['status'] as String? ?? 'upcoming').toLowerCase();
      return status == 'inprogress' || status == 'upcoming';
    }).toList()
      ..sort((a, b) {
        final timeA = a['start_time'] as String? ?? '';
        final timeB = b['start_time'] as String? ?? '';
        return timeA.compareTo(timeB);
      });
  }

  List<Map<String, dynamic>> _getUpcomingPrayers() {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    return _allPrayers.where((prayer) {
      final prayerDate = prayer['prayer_date'] as String?;
      final status = (prayer['status'] as String? ?? 'upcoming').toLowerCase();
      
      // Only show upcoming prayers from today onwards
      return prayerDate != null && 
             (prayerDate.compareTo(todayStr) > 0 || 
              (prayerDate == todayStr && status == 'upcoming')) &&
             status != 'completed';
    }).toList()
      ..sort((a, b) {
        final dateA = a['prayer_date'] as String? ?? '';
        final dateB = b['prayer_date'] as String? ?? '';
        if (dateA != dateB) return dateA.compareTo(dateB);
        final timeA = a['start_time'] as String? ?? '';
        final timeB = b['start_time'] as String? ?? '';
        return timeA.compareTo(timeB);
      });
  }

  List<Map<String, dynamic>> _getPastPrayers() {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    return _allPrayers.where((prayer) {
      final prayerDate = prayer['prayer_date'] as String?;
      final status = (prayer['status'] as String? ?? 'upcoming').toLowerCase();
      
      return prayerDate != null && 
             (prayerDate.compareTo(todayStr) < 0 || 
              (prayerDate == todayStr && status == 'completed'));
    }).toList()
      ..sort((a, b) {
        final dateA = a['prayer_date'] as String? ?? '';
        final dateB = b['prayer_date'] as String? ?? '';
        if (dateA != dateB) return dateB.compareTo(dateA); // Reverse order for past
        final timeA = a['start_time'] as String? ?? '';
        final timeB = b['start_time'] as String? ?? '';
        return timeB.compareTo(timeA);
      });
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "TBD";
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final time = TimeOfDay(hour: hour, minute: minute);
        return time.format(context);
      }
    } catch (e) {
      print("Error parsing time: $e");
    }
    return timeStr;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "TBD";
    try {
      final parts = dateStr.split('-');
      if (parts.length >= 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        final date = DateTime(year, month, day);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));
        final prayerDate = DateTime(year, month, day);
        
        if (prayerDate == today) {
          return "Today";
        } else if (prayerDate == tomorrow) {
          return "Tomorrow";
        } else {
          return DateFormat('MMM d, y').format(date);
        }
      }
    } catch (e) {
      print("Error parsing date: $e");
    }
    return dateStr;
  }

  Widget _buildStatusTag(String status) {
    String displayText;
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'inprogress':
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

    if (status.toLowerCase() == 'inprogress') {
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
    final prayerDate = prayer['prayer_date'] as String?;
    final startTime = prayer['start_time'] as String?;
    final endTime = prayer['end_time'] as String?;
    final status = (prayer['status'] as String? ?? 'upcoming').toLowerCase();
    final prayerType = (prayer['prayer_type'] as String? ?? 'offline').toLowerCase();
    final location = prayer['location'] as String?;

    String timeDisplay = "TBD";
    if (startTime != null && endTime != null) {
      timeDisplay = "${_formatTime(startTime)} - ${_formatTime(endTime)}";
    } else if (startTime != null) {
      timeDisplay = _formatTime(startTime);
    }

    final isLive = status == 'inprogress';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isLive ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLive 
          ? BorderSide(color: Colors.red[400]!, width: 2)
          : BorderSide.none,
      ),
      color: isLive ? Colors.red[50]?.withAlpha((255 * 0.3).round()) : null,
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
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLive ? Colors.red[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: isLive 
                    ? Border.all(color: Colors.red[300]!, width: 1.5)
                    : null,
                ),
                child: Icon(
                  Icons.favorite,
                  color: isLive ? Colors.red[700] : Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(prayerDate),
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          timeDisplay,
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    if (prayerType == 'offline')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location ?? "Location TBD",
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (prayerType == 'online')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.chat, size: 14, color: Colors.green[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "Join via WhatsApp",
                                style: TextStyle(fontSize: 14, color: Colors.green[600], fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayersList(List<Map<String, dynamic>> prayers) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (prayers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _selectedTabIndex == 0 
                ? "No prayers scheduled for today"
                : _selectedTabIndex == 1
                  ? "No upcoming prayers"
                  : "No past prayers",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Please check back later",
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPrayers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: prayers.length,
        itemBuilder: (context, index) {
          return _buildPrayerCard(prayers[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Prayer Schedule"),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            setState(() {
              _selectedTabIndex = index;
              if (index == 0) {
                _startAutoRefresh(); // Restart auto-refresh for Today tab
              } else {
                _refreshTimer?.cancel(); // Stop auto-refresh for other tabs
              }
            });
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPrayersList(_getTodayPrayers()),
          _buildPrayersList(_getUpcomingPrayers()),
          _buildPrayersList(_getPastPrayers()),
        ],
      ),
    );
  }
}

