import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import '../auth/auth_service.dart';
import '../services/prayer_service.dart';
import 'create_prayer_screen.dart';

class PastorHomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  
  const PastorHomeScreen({super.key, this.onNavigateToTab});

  @override
  State<PastorHomeScreen> createState() => _PastorHomeScreenState();
}

class _PastorHomeScreenState extends State<PastorHomeScreen> with WidgetsBindingObserver {
  String? pastorName;
  bool loading = true;
  bool loadingPrayers = false;
  List<Map<String, dynamic>> todayPrayers = [];
  int totalTodayPrayers = 0; // Total count before limiting to 5
  
  Timer? _autoRefreshTimer;
  static const Duration _autoRefreshInterval = Duration(seconds: 45); // 45 seconds - balance between updates and battery

  // Mock stats - replace with API calls later
  int totalMembers = 125;
  int totalFamilies = 45;
  int upcomingEvents = 3;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPastorInfo();
    _loadTodayPrayers();
    _startAutoRefresh();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Force refresh when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _loadTodayPrayers();
      _startAutoRefresh(); // Restart timer
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _autoRefreshTimer?.cancel(); // Stop timer when app goes to background
    }
  }
  
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (timer) {
      if (mounted) {
        _loadTodayPrayers(silent: true); // Silent refresh - no loading indicator
      }
    });
  }

  // This will be called manually when needed (e.g., after creating a prayer)

  Future<void> _loadPastorInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      pastorName = prefs.getString("name") ?? prefs.getString("username") ?? "Pastor";
      loading = false;
    });
  }

  Future<void> _loadTodayPrayers({bool silent = false}) async {
    if (loadingPrayers) return; // Prevent multiple simultaneous requests
    
    if (!silent) {
      setState(() {
        loadingPrayers = true;
      });
    }

    try {
      final allPrayers = await PrayerService.getAllPrayers();
      print("Loaded ${allPrayers.length} prayers from API");
      
      // Filter prayers for today
      final today = DateTime.now();
      final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      print("Filtering for today's date: $todayStr");
      
      // Filter prayers for today AND exclude completed (only show Upcoming + In Progress)
      final todayPrayersList = allPrayers.where((prayer) {
        final prayerDate = prayer['prayer_date'] as String?;
        final status = (prayer['status'] as String? ?? '').toLowerCase();
        // Only show today's prayers that are upcoming or inprogress (exclude completed)
        return prayerDate != null && 
               prayerDate.startsWith(todayStr) &&
               (status == 'upcoming' || status == 'inprogress');
      }).toList();

      print("Found ${todayPrayersList.length} active prayers for today (excluding completed)");

      // Sort by start_time (ascending - earliest first)
      todayPrayersList.sort((a, b) {
        final aTime = a['start_time'] as String? ?? '';
        final bTime = b['start_time'] as String? ?? '';
        return aTime.compareTo(bTime);
      });

      // Get only the first 5 prayers (after sorting by time)
      final limitedPrayers = todayPrayersList.take(5).toList();

      if (mounted) {
        setState(() {
          todayPrayers = limitedPrayers;
          totalTodayPrayers = todayPrayersList.length; // Store total count
          loadingPrayers = false;
        });
      }
    } catch (e) {
      print("Error loading today's prayers: $e");
      if (mounted) {
        setState(() {
          loadingPrayers = false;
          if (!silent) {
            todayPrayers = []; // Clear on error only if not silent
            totalTodayPrayers = 0; // Reset count on error only if not silent
          }
        });
        // Show error only if not silent refresh
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to load prayers: ${e.toString()}"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomScrollView(
      slivers: [
          // App Bar with greeting
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Colors.blue[700],
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                "${_getGreeting()}, ${pastorName ?? 'Pastor'}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                color: Colors.white,
                tooltip: "Notifications",
                onPressed: () {
                  // TODO: Navigate to notifications
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Notifications - Coming soon")),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                color: Colors.white,
                tooltip: "Logout",
                onPressed: _logout,
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Card
                  _buildHeroCard(),

                  const SizedBox(height: 24),

                  // Quick Stats
                  _buildQuickStats(),

                  const SizedBox(height: 24),

                  // Primary CTA - Create Prayer (moved up for visibility and reachability)
                  _buildCreatePrayerCTA(),

                  const SizedBox(height: 24),

                  // Upcoming Events
                  _buildUpcomingEvents(),

                  const SizedBox(height: 24),

                  // Today's Schedule
                  _buildTodaySchedule(),

                  const SizedBox(height: 24),

                  // Secondary Actions
                  _buildSecondaryActions(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[700]!,
            Colors.blue[900]!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background icon - subtle watermark (bottom-right, small, low opacity)
          Positioned(
            right: 16,
            bottom: 16,
            child: Icon(
              Icons.church,
              size: 56, // Reduced from 80 to make it less prominent
              color: Colors.white.withOpacity(0.12), // Much lower opacity - true background watermark
            ),
          ),
          // Dark overlay to protect text contrast
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4), // Keeps text readable
                ),
              ),
            ),
          ),
          // Foreground text content (dominant element)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Today's Fellowship",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Serving with faith and love",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Stats",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                "Members",
                totalMembers.toString(),
                Icons.people,
                Colors.blue,
                () {
                  // Navigate to Members tab
                  widget.onNavigateToTab?.call(2);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                "Families",
                totalFamilies.toString(),
                Icons.family_restroom,
                Colors.green,
                () {
                  // TODO: Navigate to Families
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Families - Coming soon")),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                "Events",
                upcomingEvents.toString(),
                Icons.event,
                Colors.orange,
                () {
                  // Navigate to Events tab
                  widget.onNavigateToTab?.call(1);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Schedule",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (loadingPrayers)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadTodayPrayers,
                tooltip: "Refresh",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: loadingPrayers
              ? const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              : todayPrayers.isEmpty
                  ? _buildEmptyScheduleState()
                  : Column(
                      children: [
                        for (int i = 0; i < todayPrayers.length; i++) ...[
                          if (i > 0) const Divider(height: 24),
                          _buildPrayerScheduleItem(todayPrayers[i]),
                        ],
                        // Show "View All" if there are more than 5 prayers
                        if (totalTodayPrayers > 5)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: TextButton.icon(
                              onPressed: () {
                                widget.onNavigateToTab?.call(1); // Navigate to Events tab to see all
                              },
                              icon: const Icon(Icons.arrow_forward, size: 18),
                              label: Text("View All (${totalTodayPrayers} total)"),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue[700],
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildPrayerScheduleItem(Map<String, dynamic> prayer) {
    // Parse time from "HH:MM:SS" format
    String formatTime(String? timeStr) {
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

    final title = prayer['title'] as String? ?? 'Prayer';
    final startTime = prayer['start_time'] as String?;
    final endTime = prayer['end_time'] as String?;
    final status = (prayer['status'] as String? ?? 'upcoming').toLowerCase();
    
    String timeDisplay = "TBD";
    if (startTime != null && endTime != null) {
      timeDisplay = "${formatTime(startTime)} - ${formatTime(endTime)}";
    } else if (startTime != null) {
      timeDisplay = formatTime(startTime);
    }

    return _buildScheduleItem(
      icon: Icons.favorite,
      title: title,
      time: timeDisplay,
      location: "Main Prayer Hall", // Default location for prayers
      status: status, // Add status for tag display
    );
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

  Widget _buildUpcomingEvents() {
    // TODO: Replace with real events data when Events backend is implemented
    // For now, show placeholder/empty state
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Upcoming Events",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {
                widget.onNavigateToTab?.call(1); // Navigate to Events tab
              },
              child: const Text("View All"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue[700],
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  "No upcoming events",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Events will appear here when created",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyScheduleState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            "No prayers scheduled today",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Take rest or plan ahead",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreatePrayerScreen(
                  onPrayerCreated: () {
                    // Refresh prayers after creating
                    _loadTodayPrayers();
                    // Navigate to Events tab
                    widget.onNavigateToTab?.call(1);
                  },
                )),
              ).then((_) {
                // Refresh prayers when returning from Create Prayer screen
                _loadTodayPrayers();
              });
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Create Prayer"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue[700],
              side: BorderSide(color: Colors.blue[700]!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem({
    required IconData icon,
    required String title,
    required String time,
    required String location,
    String? status,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.blue[700], size: 24),
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
                  if (status != null) ...[
                    const SizedBox(width: 8),
                    _buildStatusTag(status),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    time,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
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
          ),
        ),
      ],
    );
  }

  /// Primary CTA - Create Prayer button (moved up for better visibility)
  Widget _buildCreatePrayerCTA() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreatePrayerScreen(
                onPrayerCreated: () {
                  // Refresh prayers after creating
                  _loadTodayPrayers();
                  // Navigate to Events tab when prayer is created and "View Schedule" is clicked
                  widget.onNavigateToTab?.call(1);
                },
              ),
            ),
          );
          // Refresh prayers when returning from Create Prayer screen
          _loadTodayPrayers();
        },
        icon: const Icon(Icons.add_circle_outline, size: 24),
        label: const Text(
          "Create Prayer",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  /// Secondary actions (Create Event, View Members)
  Widget _buildSecondaryActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "More Actions",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Navigate to Create Event screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Create Event - Navigate to create screen"),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text("Create Event"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.blue[700]!),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // Navigate to Members tab
                  widget.onNavigateToTab?.call(2);
                },
                icon: const Icon(Icons.people),
                label: const Text("View Members"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.blue[700]!),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

