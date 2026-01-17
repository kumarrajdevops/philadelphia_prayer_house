import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/prayer_service.dart';
import '../services/event_service.dart';
import 'create_prayer_screen.dart';
import 'create_event_screen.dart';
import 'edit_prayer_screen.dart';
import 'prayer_details_screen.dart';
import 'event_details_screen.dart';
import 'edit_event_screen.dart';

class PastorEventsScreen extends StatefulWidget {
  const PastorEventsScreen({super.key});

  @override
  State<PastorEventsScreen> createState() => _PastorEventsScreenState();
}

class _PastorEventsScreenState extends State<PastorEventsScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _mainTabController; // For Prayers | Events
  late TabController _prayerFilterController; // For Today | Upcoming | Past
  late TabController _eventFilterController; // For Today | Upcoming | Past (Events)
  List<Map<String, dynamic>> allPrayers = [];
  List<Map<String, dynamic>> allEvents = [];
  bool loading = false;
  bool loadingEvents = false;
  String? error;
  int prayerFilterIndex = 0; // 0=Today, 1=Upcoming, 2=Past
  int eventFilterIndex = 0; // 0=Today, 1=Upcoming, 2=Past
  
  Timer? _autoRefreshTimer;
  static const Duration _autoRefreshInterval = Duration(seconds: 45); // 45 seconds - balance between updates and battery

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mainTabController = TabController(length: 2, vsync: this); // Prayers | Events
    _prayerFilterController = TabController(length: 3, vsync: this); // Today | Upcoming | Past
    _eventFilterController = TabController(length: 3, vsync: this); // Today | Upcoming | Past (Events)
    _loadPrayers();
    _loadEvents();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _mainTabController.dispose();
    _prayerFilterController.dispose();
    _eventFilterController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Force refresh when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _loadPrayers();
      _startAutoRefresh(); // Restart timer
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _autoRefreshTimer?.cancel(); // Stop timer when app goes to background
    }
  }
  
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (timer) {
      if (mounted) {
        if (_mainTabController.index == 0 && prayerFilterIndex == 0) {
          // Prayers tab, Today filter
          _loadPrayers(silent: true);
        } else if (_mainTabController.index == 1 && eventFilterIndex == 0) {
          // Events tab, Today filter
          _loadEvents(silent: true);
        }
      }
    });
  }

  Future<void> _loadPrayers({bool silent = false}) async {
    if (loading && !silent) return; // Allow silent refresh even if loading

    if (!silent) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      // Use occurrences API (loads all occurrences, we filter by tab client-side)
      final prayers = await PrayerService.getPrayerOccurrences();
      print("Loaded ${prayers.length} prayer occurrences for Events tab");

      // Sort by start_datetime (ascending)
      prayers.sort((a, b) {
        final aStart = a['start_datetime'] as String? ?? '';
        final bStart = b['start_datetime'] as String? ?? '';
        return aStart.compareTo(bStart);
      });

      if (mounted) {
        setState(() {
          allPrayers = prayers;
          loading = false;
        });
      }
    } catch (e) {
      print("Error loading prayers: $e");
      if (mounted) {
        setState(() {
          loading = false;
          if (!silent) {
            error = "Failed to load prayers: ${e.toString()}";
          }
        });
      }
    }
  }

  List<Map<String, dynamic>> _getPrayersForTab(int index) {
    final now = DateTime.now();

    switch (index) {
      case 0: // Today: Ongoing OR starts today (but NOT completed)
        return allPrayers.where((prayer) {
          final startStr = prayer['start_datetime'] as String?;
          final endStr = prayer['end_datetime'] as String?;
          final status = (prayer['status'] as String? ?? '').toLowerCase();
          
          if (startStr == null || endStr == null) return false;
          
          // Exclude completed prayers from Today tab
          if (status == 'completed') return false;
          
          try {
            final start = DateTime.parse(startStr).toLocal();
            final end = DateTime.parse(endStr).toLocal();
            final todayStart = DateTime(now.year, now.month, now.day);
            final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
            
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
            return startA.compareTo(startB); // Ascending order (earliest first)
          });
      case 1: // Upcoming: Future prayers (date > today, not completed, exclude today's prayers)
        return allPrayers.where((prayer) {
          final startStr = prayer['start_datetime'] as String?;
          final status = (prayer['status'] as String? ?? '').toLowerCase();
          if (startStr == null) return false;
          
          try {
            final start = DateTime.parse(startStr).toLocal();
            final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
            
            // Show future prayers that start after today (tomorrow or later)
            // Exclude today's prayers (they should be in Today tab)
            return start.isAfter(todayEnd) && status != 'completed';
          } catch (e) {
            return false;
          }
        }).toList()
          ..sort((a, b) {
            final startA = a['start_datetime'] as String? ?? '';
            final startB = b['start_datetime'] as String? ?? '';
            return startA.compareTo(startB); // Ascending order (earliest first)
          });
      case 2: // Past: Completed prayers (end_datetime < now, or status = completed)
        return allPrayers.where((prayer) {
          final startStr = prayer['start_datetime'] as String?;
          final endStr = prayer['end_datetime'] as String?;
          final status = (prayer['status'] as String? ?? '').toLowerCase();
          
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
            return startB.compareTo(startA); // Descending order (latest first)
          });
      default:
        return [];
    }
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
    if (dateStr == null || dateStr.isEmpty) return "Unknown";
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
        final dateOnly = DateTime(date.year, date.month, date.day);
        
        if (dateOnly == today) {
          return "Today";
        } else if (dateOnly == tomorrow) {
          return "Tomorrow";
        } else {
          // Format as "Mon, Jan 15" or "Mon, Jan 15, 2024" if different year
          final weekday = _getWeekday(date.weekday);
          final monthName = _getMonthName(month);
          if (date.year == now.year) {
            return "$weekday, $monthName $day";
          } else {
            return "$weekday, $monthName $day, $year";
          }
        }
      }
    } catch (e) {
      print("Error parsing date: $e");
    }
    return dateStr;
  }

  String _getWeekday(int weekday) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  /// Check if prayer has started (compare start_datetime with current time)
  bool _hasPrayerStarted(Map<String, dynamic> prayer) {
    final startStr = prayer['start_datetime'] as String?;
    
    if (startStr == null) {
      return false; // If no datetime, assume it hasn't started (safe default)
    }
    
    try {
      final start = DateTime.parse(startStr).toLocal();
      final now = DateTime.now();
      
      // Check if prayer has started (including current moment)
      return start.isBefore(now) || start.isAtSameMomentAs(now);
    } catch (e) {
      print("Error checking if prayer started: $e");
      return false; // Safe default: assume it hasn't started
    }
  }

  Future<void> _handleEditPrayer(Map<String, dynamic> prayer) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditPrayerScreen(
          prayer: prayer,
          onPrayerUpdated: () {
            // Refresh prayers after editing
            _loadPrayers();
          },
        ),
      ),
    );
    // Also refresh when returning from edit screen
    _loadPrayers();
  }

  Future<void> _handleDeletePrayer(Map<String, dynamic> prayer) async {
    final prayerId = prayer['id'] as int?;
    if (prayerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid prayer ID")),
      );
      return;
    }
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Prayer?"),
        content: const Text("Members will no longer see this prayer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // Show loading indicator
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            ),
            SizedBox(width: 16),
            Text("Deleting prayer..."),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
    
    try {
      final success = await PrayerService.deletePrayerOccurrence(occurrenceId: prayerId);
      
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Prayer deleted successfully"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Refresh prayer list
        _loadPrayers();
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to delete prayer"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Extract friendly error message from exception
      String errorMessage = e.toString().replaceFirst("Exception: ", "");
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleCreateAction() {
    // Always show dialog with options (Prayer or Event)
    _showCreateOptionsDialog();
  }

  void _showCreateOptionsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle, color: Colors.blue, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text("Create New")),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("What would you like to create?"),
            const SizedBox(height: 20),
            // Create Prayer option
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreatePrayerScreen(
                      onPrayerCreated: () {
                        // Refresh prayers after creating and clicking "View Schedule"
                        _loadPrayers();
                      },
                    ),
                  ),
                ).then((_) {
                  // Refresh prayers after returning from Create Prayer screen
                  // (covers "Create Another" button or back button)
                  _loadPrayers();
                });
              },
              icon: const Icon(Icons.favorite, size: 20),
              label: const Text("Create Prayer"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue[700],
                side: BorderSide(color: Colors.blue[700]!),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            // Create Event option
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateEventScreen(
                      onEventCreated: () {
                        _loadEvents();
                      },
                    ),
                  ),
                ).then((_) {
                  _loadEvents();
                });
              },
              icon: const Icon(Icons.event, size: 20),
              label: const Text("Create Event"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Prayers & Events"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _mainTabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Prayers", icon: Icon(Icons.favorite, size: 20)),
            Tab(text: "Events", icon: Icon(Icons.event, size: 20)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Create",
            onPressed: _handleCreateAction,
          ),
          IconButton(
            icon: loading ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ) : const Icon(Icons.refresh),
            tooltip: "Refresh",
            onPressed: loading || loadingEvents ? null : () {
              if (_mainTabController.index == 0) {
                _loadPrayers();
              } else {
                _loadEvents();
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _mainTabController,
        children: [
          // Prayers Tab
          _buildPrayersTab(),
          // Events Tab
          _buildEventsTab(),
        ],
      ),
    );
  }

  Widget _buildPrayersTab() {
    if (loading && allPrayers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && allPrayers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                error!,
                style: TextStyle(color: Colors.red[700]),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadPrayers,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Filter tabs: Today, Upcoming, Past
        Container(
          color: Colors.grey[100],
          child: TabBar(
            controller: _prayerFilterController,
            indicatorColor: Colors.blue[700],
            labelColor: Colors.blue[700],
            unselectedLabelColor: Colors.grey[600],
            tabs: const [
              Tab(text: "Today"),
              Tab(text: "Upcoming"),
              Tab(text: "Past"),
            ],
            onTap: (index) {
              setState(() {
                prayerFilterIndex = index;
              });
            },
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _prayerFilterController,
            children: [
              _buildPrayersList(0), // Today
              _buildPrayersList(1), // Upcoming
              _buildPrayersList(2), // Past
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrayersList(int filterIndex) {
    final prayers = _getPrayersForTab(filterIndex);

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
              _getEmptyMessage(filterIndex),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Create a prayer to get started",
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreatePrayerScreen(
                      onPrayerCreated: () {
                        // Refresh prayers after creating and clicking "View Schedule"
                        _loadPrayers();
                      },
                    ),
                  ),
                );
                // Refresh prayers when returning from Create Prayer screen
                _loadPrayers();
              },
              icon: const Icon(Icons.add),
              label: const Text("Create Prayer"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
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
          final prayer = prayers[index];
          return _buildPrayerCard(prayer);
        },
      ),
    );
  }

  String _getEmptyMessage(int filterIndex) {
    switch (filterIndex) {
      case 0: // Today
        return "No active prayers for today";
      case 1: // Upcoming
        return "No upcoming prayers";
      case 2: // Past
        return "No completed prayers";
      default:
        return "No prayers";
    }
  }

  /// Build status tag widget with visual emphasis for LIVE NOW
  Widget _buildStatusTag(String status) {
    String displayText;
    Color backgroundColor;
    Color textColor;
    
    switch (status.toLowerCase()) {
      case 'ongoing':
        // LIVE NOW - more prominent visual emphasis
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
    
    // Special styling for LIVE NOW (ongoing)
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
            // Pulsing dot indicator
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
    
    // Regular styling for other statuses
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
    final status = (prayer['status'] as String? ?? 'upcoming').toLowerCase();
    final prayerType = (prayer['prayer_type'] as String? ?? 'offline').toLowerCase();
    final location = prayer['location'] as String?;
    final joinInfo = prayer['join_info'] as String?;
    final canEdit = status == 'upcoming'; // Only show edit/delete if status is upcoming

    String dateTimeDisplay = "TBD";
    String dateDisplay = "TBD";
    String timeDisplay = "TBD";
    if (startStr != null && endStr != null) {
      try {
        final start = DateTime.parse(startStr).toLocal();
        final end = DateTime.parse(endStr).toLocal();
        if (start.year == end.year && start.month == end.month && start.day == end.day) {
          // Same day
          dateDisplay = DateFormat('MMM d, y').format(start);
          timeDisplay = "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}";
        } else {
          // Multi-day
          dateDisplay = "${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, y').format(end)}";
          timeDisplay = "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}";
        }
      } catch (e) {
        dateDisplay = "TBD";
        timeDisplay = "$startStr - $endStr";
      }
    }

    final isLive = status == 'ongoing';
    
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
      elevation: isLive ? 4 : 2, // Higher elevation for live prayers
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLive 
          ? BorderSide(color: Colors.red[400]!, width: 2) // Red border for live prayers
          : BorderSide.none,
      ),
      color: isLive ? Colors.red[50]?.withAlpha((255 * 0.3).round()) : null, // Subtle background tint for live
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PrayerDetailsScreen(
                prayer: prayer,
                onPrayerUpdated: () {
                  _loadPrayers();
                },
                onPrayerDeleted: () {
                  _loadPrayers();
                },
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: isLive 
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
                        // Prayer Type Badge (for online prayers)
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
                          ),
                        // Prayer Type Badge (for offline prayers)
                        if (prayerType == 'offline')
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dateDisplay,
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Show time
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
                            timeDisplay,
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                    // Show location for offline prayers, WhatsApp info for online prayers
                    if (prayerType == 'offline')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                            ),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(Icons.chat, size: 14, color: Colors.green[600]),
                            ),
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
                    // Show edit and delete buttons at the bottom only if prayer hasn't started
                    if (canEdit) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              _handleEditPrayer(prayer);
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                            label: const Text(
                              "Edit",
                              style: TextStyle(color: Colors.blue),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () {
                              _handleDeletePrayer(prayer);
                            },
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            label: const Text(
                              "Delete",
                              style: TextStyle(color: Colors.red),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Future<void> _loadEvents({bool silent = false}) async {
    if (loadingEvents && !silent) return;

    if (!silent) {
      setState(() {
        loadingEvents = true;
        error = null;
      });
    }

    try {
      final events = await EventService.getEventOccurrences();
      print("Loaded ${events.length} events");
      
      // Debug: Print all events
      for (var event in events) {
        print("Event: ${event['title']} | Start: ${event['start_datetime']} | End: ${event['end_datetime']} | Status: ${event['status']}");
      }

      // Sort by start_datetime
      events.sort((a, b) {
        final aStart = a['start_datetime'] as String? ?? '';
        final bStart = b['start_datetime'] as String? ?? '';
        return aStart.compareTo(bStart);
      });

      if (mounted) {
        setState(() {
          allEvents = events;
          loadingEvents = false;
        });
      }
    } catch (e) {
      print("Error loading events: $e");
      if (mounted) {
        setState(() {
          loadingEvents = false;
          if (!silent) {
            error = "Failed to load events: ${e.toString()}";
          }
        });
      }
    }
  }

  List<Map<String, dynamic>> _getEventsForTab(int index) {
    final now = DateTime.now();

    switch (index) {
      case 0: // Today: Ongoing OR starts today (but NOT completed)
        return allEvents.where((event) {
          final startStr = event['start_datetime'] as String?;
          final endStr = event['end_datetime'] as String?;
          final status = (event['status'] as String? ?? '').toLowerCase();
          
          if (startStr == null || endStr == null) return false;
          
          // Exclude completed events from Today tab
          if (status == 'completed') return false;
          
          try {
            final start = DateTime.parse(startStr).toLocal();
            final end = DateTime.parse(endStr).toLocal();
            final todayStart = DateTime(now.year, now.month, now.day);
            final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
            
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
            return startA.compareTo(startB); // Ascending order (earliest first)
          });
      case 1: // Upcoming: Future events (date > today, not completed, exclude today's events)
        return allEvents.where((event) {
          final startStr = event['start_datetime'] as String?;
          final status = (event['status'] as String? ?? '').toLowerCase();
          if (startStr == null) return false;
          
          try {
            final start = DateTime.parse(startStr).toLocal();
            final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
            
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
            return startA.compareTo(startB); // Ascending order (earliest first)
          });
      case 2: // Past: Completed events (end_datetime < now, or status = completed)
        return allEvents.where((event) {
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
            return startB.compareTo(startA); // Descending order (latest first)
          });
      default:
        return [];
    }
  }

  Widget _buildEventsTab() {
    if (loadingEvents && allEvents.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && allEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                error!,
                style: TextStyle(color: Colors.red[700]),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: Colors.grey[100],
          child: TabBar(
            controller: _eventFilterController,
            indicatorColor: Colors.blue[700],
            labelColor: Colors.blue[700],
            unselectedLabelColor: Colors.grey[600],
            tabs: const [
              Tab(text: "Today"),
              Tab(text: "Upcoming"),
              Tab(text: "Past"),
            ],
            onTap: (index) {
              setState(() {
                eventFilterIndex = index;
              });
            },
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _eventFilterController,
            children: [
              _buildEventsList(0), // Today
              _buildEventsList(1), // Upcoming
              _buildEventsList(2), // Past
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventsList(int filterIndex) {
    final events = _getEventsForTab(filterIndex);
    
    // Debug: Print filtered events
    print("Tab $filterIndex: ${events.length} events");
    for (var event in events) {
      print("  - ${event['title']} | Status: ${event['status']}");
    }

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _getEventEmptyMessage(filterIndex),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Create an event to get started",
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateEventScreen(
                      onEventCreated: () {
                        _loadEvents();
                      },
                    ),
                  ),
                );
                _loadEvents();
              },
              icon: const Icon(Icons.add),
              label: const Text("Create Event"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return _buildEventCard(event);
        },
      ),
    );
  }

  String _getEventEmptyMessage(int filterIndex) {
    switch (filterIndex) {
      case 0:
        return "No events for today";
      case 1:
        return "No upcoming events";
      case 2:
        return "No past events";
      default:
        return "No events";
    }
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final title = event['title'] as String? ?? 'Event';
    final startStr = event['start_datetime'] as String?;
    final endStr = event['end_datetime'] as String?;
    final status = (event['status'] as String? ?? 'upcoming').toLowerCase();
    final location = event['location'] as String?;
    final recurrenceType = event['recurrence_type'] as String?;
    final canEdit = status == 'upcoming';

    String dateDisplay = "TBD";
    String timeDisplay = "TBD";
    if (startStr != null && endStr != null) {
      try {
        final start = DateTime.parse(startStr).toLocal();
        final end = DateTime.parse(endStr).toLocal();
        if (start.year == end.year && start.month == end.month && start.day == end.day) {
          // Same day
          dateDisplay = DateFormat('MMM d, y').format(start);
          timeDisplay = "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}";
        } else {
          // Multi-day
          dateDisplay = "${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, y').format(end)}";
          timeDisplay = "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}";
        }
      } catch (e) {
        dateDisplay = "TBD";
        timeDisplay = "$startStr - $endStr";
      }
    }

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
              builder: (_) => EventDetailsScreen(
                event: event,
                onEventUpdated: () {
                  _loadEvents();
                },
                onEventDeleted: () {
                  _loadEvents();
                },
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        _buildEventStatusTag(status),
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
                            dateDisplay,
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
                            timeDisplay,
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
                    if (canEdit) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditEventScreen(
                                    event: event,
                                    onEventUpdated: () {
                                      _loadEvents();
                                    },
                                  ),
                                ),
                              ).then((_) {
                                // Refresh events when returning from edit screen
                                _loadEvents();
                              });
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                            label: const Text("Edit", style: TextStyle(color: Colors.blue)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () {
                              _handleDeleteEvent(event);
                            },
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            label: const Text("Delete", style: TextStyle(color: Colors.red)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Widget _buildEventStatusTag(String status) {
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

  Future<void> _handleDeleteEvent(Map<String, dynamic> event) async {
    final eventId = event['id'] as int?;
    if (eventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid event ID")),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Event?"),
        content: const Text("This will delete this event occurrence. Past events will remain for records."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await EventService.deleteEventOccurrence(occurrenceId: eventId);
      
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Event deleted successfully"),
            backgroundColor: Colors.green,
          ),
        );
        _loadEvents();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to delete event"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst("Exception: ", "")),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
