import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import '../auth/auth_service.dart';
import '../services/profile_service.dart';
import '../utils/api_client.dart';
import 'pastor_home_screen.dart';
import 'pastor_events_screen.dart';
import 'pastor_members_screen.dart';
import 'pastor_gallery_screen.dart';
import 'pastor_prayer_requests_screen.dart';
import '../member/member_settings_screen.dart';

class PastorShell extends StatefulWidget {
  const PastorShell({super.key});

  @override
  State<PastorShell> createState() => _PastorShellState();
}

class _PastorShellState extends State<PastorShell> {
  int _currentIndex = 0;
  String? pastorName;
  String? profileImageUrl;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      PastorHomeScreen(onNavigateToTab: _onTabTapped),
      const PastorEventsScreen(),
      const PastorMembersScreen(),
      const PastorGalleryScreen(),
    ];
    _loadPastorInfo();
  }

  Future<void> _loadPastorInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      pastorName = prefs.getString("name") ?? prefs.getString("username") ?? "Pastor";
    });
    
    // Load profile image
    try {
      final profile = await ProfileService.getProfile();
      if (profile != null && mounted) {
        setState(() {
          profileImageUrl = profile["profile_image_url"];
        });
      }
    } catch (e) {
      // Silently fail - profile image is optional
      print("Failed to load profile image: $e");
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }


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

    if (confirmed == true) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      drawer: _buildDrawer(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue[700],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  backgroundImage: profileImageUrl != null && profileImageUrl!.isNotEmpty
                      ? NetworkImage("${ApiClient.baseUrl}/uploads/$profileImageUrl")
                      : null,
                  child: profileImageUrl == null || profileImageUrl!.isEmpty
                      ? Text(
                          pastorName?.substring(0, 1).toUpperCase() ?? "P",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  pastorName ?? "Pastor",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Pastor",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Profile"),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to profile
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Profile - Coming soon")),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text("Calendar"),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to calendar
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Calendar - Coming soon")),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text("Prayer Requests"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PastorPrayerRequestsScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text("Help & Support"),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to help
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Help & Support - Coming soon")),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Settings"),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MemberSettingsScreen(),
                ),
              );
              // Refresh profile info when returning from Settings
              _loadPastorInfo();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onTabTapped,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: Colors.blue[700],
      unselectedItemColor: Colors.grey[600],
      selectedFontSize: 13,
      unselectedFontSize: 12,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
      ),
      elevation: 8,
      items: [
        BottomNavigationBarItem(
          icon: Icon(
            _currentIndex == 0 ? Icons.home : Icons.home_outlined,
          ),
          activeIcon: const Icon(Icons.home),
          label: "Home",
        ),
        BottomNavigationBarItem(
          icon: Icon(
            _currentIndex == 1 ? Icons.event : Icons.event_outlined,
          ),
          activeIcon: const Icon(Icons.event),
          label: "Events",
        ),
        BottomNavigationBarItem(
          icon: Icon(
            _currentIndex == 2 ? Icons.people : Icons.people_outline,
          ),
          activeIcon: const Icon(Icons.people),
          label: "Members",
        ),
        BottomNavigationBarItem(
          icon: Icon(
            _currentIndex == 3 ? Icons.photo_library : Icons.photo_library_outlined,
          ),
          activeIcon: const Icon(Icons.photo_library),
          label: "Gallery",
        ),
      ],
    );
  }
}

