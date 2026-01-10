import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import '../auth/auth_service.dart';

class PastorHomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  
  const PastorHomeScreen({super.key, this.onNavigateToTab});

  @override
  State<PastorHomeScreen> createState() => _PastorHomeScreenState();
}

class _PastorHomeScreenState extends State<PastorHomeScreen> {
  String? pastorName;
  bool loading = true;

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
    _loadPastorInfo();
  }

  Future<void> _loadPastorInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      pastorName = prefs.getString("name") ?? prefs.getString("username") ?? "Pastor";
      loading = false;
    });
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
    // TODO: Replace with actual schedule data from API
    final todayEvents = <Map<String, dynamic>>[
      {
        'icon': Icons.favorite,
        'title': "Morning Prayer",
        'time': "7:00 AM",
        'location': "Main Hall",
      },
      {
        'icon': Icons.event,
        'title': "Youth Fellowship",
        'time': "6:00 PM",
        'location': "Youth Hall",
      },
    ];

    final hasEvents = todayEvents.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Schedule",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: hasEvents
              ? Column(
                  children: [
                    for (int i = 0; i < todayEvents.length; i++) ...[
                      if (i > 0) const Divider(height: 24),
                      _buildScheduleItem(
                        icon: todayEvents[i]['icon'] as IconData,
                        title: todayEvents[i]['title'] as String,
                        time: todayEvents[i]['time'] as String,
                        location: todayEvents[i]['location'] as String,
                      ),
                    ],
                  ],
                )
              : _buildEmptyScheduleState(),
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
            "No events scheduled today",
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
              widget.onNavigateToTab?.call(1); // Navigate to Events tab
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Create Event"),
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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
        onPressed: () {
          // TODO: Navigate to Create Prayer screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Create Prayer - Navigate to create screen"),
            ),
          );
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

