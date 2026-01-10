import 'package:flutter/material.dart';
import '../services/prayer_service.dart';
import 'create_prayer_screen.dart';

class PastorEventsScreen extends StatefulWidget {
  const PastorEventsScreen({super.key});

  @override
  State<PastorEventsScreen> createState() => _PastorEventsScreenState();
}

class _PastorEventsScreenState extends State<PastorEventsScreen> with TickerProviderStateMixin {
  late TabController _mainTabController; // For Prayers | Events
  late TabController _prayerFilterController; // For All | Today | Upcoming
  List<Map<String, dynamic>> allPrayers = [];
  bool loading = false;
  String? error;
  int prayerFilterIndex = 0; // 0=All, 1=Today, 2=Upcoming

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this); // Prayers | Events
    _prayerFilterController = TabController(length: 3, vsync: this); // All | Today | Upcoming
    _loadPrayers();
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _prayerFilterController.dispose();
    super.dispose();
  }

  Future<void> _loadPrayers() async {
    if (loading) return;

    setState(() {
      loading = true;
      error = null;
    });

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
          error = "Failed to load prayers: ${e.toString()}";
        });
      }
    }
  }

  List<Map<String, dynamic>> _getPrayersForTab(int index) {
    final today = DateTime.now();
    final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    switch (index) {
      case 0: // All
        return allPrayers;
      case 1: // Today
        return allPrayers.where((prayer) {
          final prayerDate = prayer['prayer_date'] as String?;
          return prayerDate != null && prayerDate.startsWith(todayStr);
        }).toList();
      case 2: // Upcoming (starting from tomorrow, excluding today)
        return allPrayers.where((prayer) {
          final prayerDate = prayer['prayer_date'] as String?;
          if (prayerDate == null) return false;
          // Only show prayers from tomorrow onwards (strictly greater than today)
          return prayerDate.compareTo(todayStr) > 0;
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
                    builder: (_) => const CreatePrayerScreen(),
                  ),
                ).then((_) {
                  _loadPrayers(); // Refresh prayers after returning
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
        // Filter tabs: All, Today, Upcoming
        Container(
          color: Colors.grey[100],
          child: TabBar(
            controller: _prayerFilterController,
            indicatorColor: Colors.blue[700],
            labelColor: Colors.blue[700],
            unselectedLabelColor: Colors.grey[600],
            tabs: const [
              Tab(text: "All"),
              Tab(text: "Today"),
              Tab(text: "Upcoming"),
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
              _buildPrayersList(0), // All
              _buildPrayersList(1), // Today
              _buildPrayersList(2), // Upcoming
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
                    builder: (_) => const CreatePrayerScreen(),
                  ),
                );
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
      case 0:
        return "No prayers yet";
      case 1:
        return "No prayers scheduled for today";
      case 2:
        return "No upcoming prayers";
      default:
        return "No prayers";
    }
  }

  Widget _buildPrayerCard(Map<String, dynamic> prayer) {
    final title = prayer['title'] as String? ?? 'Prayer';
    final prayerDate = prayer['prayer_date'] as String?;
    final startTime = prayer['start_time'] as String?;
    final endTime = prayer['end_time'] as String?;

    String timeDisplay = "TBD";
    if (startTime != null && endTime != null) {
      timeDisplay = "${_formatTime(startTime)} - ${_formatTime(endTime)}";
    } else if (startTime != null) {
      timeDisplay = _formatTime(startTime);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.favorite, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
