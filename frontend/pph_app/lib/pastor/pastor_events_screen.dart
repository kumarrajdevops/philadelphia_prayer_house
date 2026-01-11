import 'dart:async';
import 'package:flutter/material.dart';
import '../services/prayer_service.dart';
import 'create_prayer_screen.dart';

class PastorEventsScreen extends StatefulWidget {
  const PastorEventsScreen({super.key});

  @override
  State<PastorEventsScreen> createState() => _PastorEventsScreenState();
}

class _PastorEventsScreenState extends State<PastorEventsScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _mainTabController; // For Prayers | Events
  late TabController _prayerFilterController; // For Today | Upcoming | Past
  List<Map<String, dynamic>> allPrayers = [];
  bool loading = false;
  String? error;
  int prayerFilterIndex = 0; // 0=Today, 1=Upcoming, 2=Past
  
  Timer? _autoRefreshTimer;
  static const Duration _autoRefreshInterval = Duration(seconds: 45); // 45 seconds - balance between updates and battery

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mainTabController = TabController(length: 2, vsync: this); // Prayers | Events
    _prayerFilterController = TabController(length: 3, vsync: this); // Today | Upcoming | Past
    _loadPrayers();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _mainTabController.dispose();
    _prayerFilterController.dispose();
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
      if (mounted && prayerFilterIndex == 0) {
        // Only auto-refresh if on "Today" tab
        _loadPrayers(silent: true); // Silent refresh - no loading indicator
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
      final prayers = await PrayerService.getAllPrayers();
      print("Loaded ${prayers.length} prayers for Events tab");

      // Sort by date (ascending) and then by time (ascending)
      prayers.sort((a, b) {
        final aDate = a['prayer_date'] as String? ?? '';
        final bDate = b['prayer_date'] as String? ?? '';
        final dateCompare = aDate.compareTo(bDate);
        if (dateCompare != 0) return dateCompare;
        
        final aTime = a['start_time'] as String? ?? '';
        final bTime = b['start_time'] as String? ?? '';
        return aTime.compareTo(bTime);
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
    final today = DateTime.now();
    final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    switch (index) {
      case 0: // Today: In Progress (today) + Upcoming (today only)
        return allPrayers.where((prayer) {
          final prayerDate = prayer['prayer_date'] as String?;
          final status = (prayer['status'] as String? ?? '').toLowerCase();
          // Show today's prayers that are upcoming or inprogress (exclude completed)
          return prayerDate != null && 
                 prayerDate.startsWith(todayStr) &&
                 (status == 'upcoming' || status == 'inprogress');
        }).toList();
      case 1: // Upcoming: Future prayers (beyond today, status = upcoming)
        return allPrayers.where((prayer) {
          final prayerDate = prayer['prayer_date'] as String?;
          final status = (prayer['status'] as String? ?? '').toLowerCase();
          if (prayerDate == null) return false;
          // Show prayers from tomorrow onwards with status = upcoming
          return prayerDate.compareTo(todayStr) > 0 && status == 'upcoming';
        }).toList();
      case 2: // Past: Completed prayers (status = completed, any date)
        return allPrayers.where((prayer) {
          final status = (prayer['status'] as String? ?? '').toLowerCase();
          return status == 'completed';
        }).toList();
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

  /// Check if prayer has started (compare date + start_time with current time up to HH:MM precision)
  bool _hasPrayerStarted(Map<String, dynamic> prayer) {
    final prayerDate = prayer['prayer_date'] as String?;
    final startTime = prayer['start_time'] as String?;
    
    if (prayerDate == null || startTime == null) {
      return false; // If no date/time, assume it hasn't started (safe default)
    }
    
    try {
      // Parse date (YYYY-MM-DD)
      final dateParts = prayerDate.split('-');
      if (dateParts.length < 3) return false;
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);
      
      // Parse time (HH:MM:SS)
      final timeParts = startTime.split(':');
      if (timeParts.length < 2) return false;
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      // Create prayer DateTime
      final prayerDateTime = DateTime(year, month, day, hour, minute);
      final now = DateTime.now();
      
      // Truncate to minute precision for comparison
      final prayerTruncated = DateTime(year, month, day, hour, minute);
      final nowTruncated = DateTime(now.year, now.month, now.day, now.hour, now.minute);
      
      // Check if prayer has started (including current moment)
      return prayerTruncated.compareTo(nowTruncated) <= 0;
    } catch (e) {
      print("Error checking if prayer started: $e");
      return false; // Safe default: assume it hasn't started
    }
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
      final success = await PrayerService.deletePrayer(prayerId);
      
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
            // Create Event option (placeholder for now)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Create Event - Coming soon"),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                  ),
                );
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
            onPressed: loading ? null : _loadPrayers,
          ),
        ],
      ),
      body: TabBarView(
        controller: _mainTabController,
        children: [
          // Prayers Tab
          _buildPrayersTab(),
          // Events Tab (Placeholder for now)
          _buildEventsTabPlaceholder(),
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
      case 'inprogress':
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
    
    // Special styling for LIVE NOW (in-progress)
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
    final prayerDate = prayer['prayer_date'] as String?;
    final startTime = prayer['start_time'] as String?;
    final endTime = prayer['end_time'] as String?;
    final status = (prayer['status'] as String? ?? 'upcoming').toLowerCase();
    final canDelete = status == 'upcoming'; // Only show delete if status is upcoming

    String timeDisplay = "TBD";
    if (startTime != null && endTime != null) {
      timeDisplay = "${_formatTime(startTime)} - ${_formatTime(endTime)}";
    } else if (startTime != null) {
      timeDisplay = _formatTime(startTime);
    }

    final isLive = status == 'inprogress';
    
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
          // TODO: Navigate to prayer details
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Prayer details - Coming soon: $title")),
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
                        const SizedBox(width: 16),
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "Main Prayer Hall",
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Show delete button only if prayer hasn't started
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: "Delete prayer",
                  onPressed: () {
                    _handleDeletePrayer(prayer);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              if (!canDelete)
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventsTabPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "Events Management",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Coming soon",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Create Event - Coming soon")),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text("Create Event"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
