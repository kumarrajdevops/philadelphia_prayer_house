import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/login_screen.dart';
import '../auth/auth_service.dart';
import '../services/prayer_service.dart';
import '../services/event_service.dart';
import '../services/member_service.dart';
import '../utils/error_handler.dart';
import 'create_prayer_screen.dart';
import 'create_event_screen.dart';
import 'prayer_details_screen.dart';
import 'event_details_screen.dart';

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
  bool loadingEvents = false;
  List<Map<String, dynamic>> todayPrayers = [];
  int totalTodayPrayers = 0; // Total count before limiting to 5
  List<Map<String, dynamic>> livePrayers = [];
  List<Map<String, dynamic>> todayEvents = [];
  int totalTodayEvents = 0; // Total count before limiting to 5
  List<Map<String, dynamic>> liveEvents = [];
  
  Timer? _autoRefreshTimer;
  static const Duration _autoRefreshInterval = Duration(seconds: 45); // 45 seconds - balance between updates and battery

  // Stats
  int totalMembers = 0; // Active members count
  int totalFamilies = 45; // TODO: Implement families feature
  int upcomingEvents = 0; // Upcoming events count

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
    _loadTodayEvents();
    _loadActiveMembersCount();
    _loadUpcomingEventsCount();
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
      // Check if user is blocked/deleted when app resumes
      ErrorHandler.checkUserStatus(context);
      _loadTodayPrayers();
      _loadTodayEvents();
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
        _loadTodayEvents(silent: true);
        _loadActiveMembersCount(silent: true);
        _loadUpcomingEventsCount(silent: true);
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

  Future<void> _loadActiveMembersCount({bool silent = false}) async {
    try {
      // Fetch only active, non-deleted members
      final members = await MemberService.getMembers(
        isActive: true,
        isDeleted: false,
      );
      
      if (mounted) {
        setState(() {
          totalMembers = members.length;
        });
      }
    } catch (e) {
      print("Failed to load active members count: $e");
      // Don't update state on error - keep previous count
    }
  }

  Future<void> _loadUpcomingEventsCount({bool silent = false}) async {
    try {
      final allEvents = await EventService.getEventOccurrences();
      
      // Filter for upcoming events (future events, not completed)
      final now = DateTime.now();
      
      final upcomingEventsList = allEvents.where((event) {
        final startStr = event['start_datetime'] as String?;
        final status = (event['status'] as String? ?? '').toLowerCase();
        
        // Exclude completed events
        if (status == 'completed') return false;
        
        if (startStr == null) return false;
        
        try {
          final start = DateTime.parse(startStr).toLocal();
          // Count events that start in the future
          return start.isAfter(now);
        } catch (e) {
          return false;
        }
      }).toList();
      
      if (mounted) {
        setState(() {
          upcomingEvents = upcomingEventsList.length;
        });
      }
    } catch (e) {
      print("Failed to load upcoming events count: $e");
      // Don't update state on error - keep previous count
    }
  }

  Future<void> _loadTodayPrayers({bool silent = false}) async {
    if (loadingPrayers) return; // Prevent multiple simultaneous requests
    
    if (!silent) {
      setState(() {
        loadingPrayers = true;
      });
    }

    try {
      // Use occurrences API with "today" tab (already filters for today and excludes completed)
      final todayPrayersList = await PrayerService.getPrayerOccurrences(tab: "today");
      print("Loaded ${todayPrayersList.length} prayers for today from occurrences API");

      // Sort by start_datetime (ascending - earliest first)
      todayPrayersList.sort((a, b) {
        final aStart = a['start_datetime'] as String? ?? '';
        final bStart = b['start_datetime'] as String? ?? '';
        return aStart.compareTo(bStart);
      });

      // Get only the first 5 prayers (after sorting by time)
      final limitedPrayers = todayPrayersList.take(5).toList();

      // Find all live prayers (ongoing)
      final livePrayersList = todayPrayersList.where((prayer) {
        final status = (prayer['status'] as String? ?? '').toLowerCase();
        return status == 'ongoing';
      }).toList()
        ..sort((a, b) {
          final timeA = a['start_datetime'] as String? ?? '';
          final timeB = b['start_datetime'] as String? ?? '';
          return timeA.compareTo(timeB);
        });

      if (mounted) {
        setState(() {
          todayPrayers = limitedPrayers;
          totalTodayPrayers = todayPrayersList.length; // Store total count
          livePrayers = livePrayersList;
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

  Future<void> _loadTodayEvents({bool silent = false}) async {
    if (loadingEvents) return; // Prevent multiple simultaneous requests
    
    if (!silent) {
      setState(() {
        loadingEvents = true;
      });
    }

    try {
      final allEvents = await EventService.getEventOccurrences();
      print("Loaded ${allEvents.length} events from API");
      
      // Filter events for today (not completed)
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      
      final todayEventsList = allEvents.where((event) {
        final startStr = event['start_datetime'] as String?;
        final endStr = event['end_datetime'] as String?;
        final status = (event['status'] as String? ?? '').toLowerCase();
        
        if (startStr == null || endStr == null) return false;
        
        // Exclude completed events
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
      }).toList();

      print("Found ${todayEventsList.length} active events for today (excluding completed)");

      // Sort by start_datetime (ascending - earliest first)
      todayEventsList.sort((a, b) {
        final aStart = a['start_datetime'] as String? ?? '';
        final bStart = b['start_datetime'] as String? ?? '';
        return aStart.compareTo(bStart);
      });

      // Get only the first 5 events (after sorting by time)
      final limitedEvents = todayEventsList.take(5).toList();

      // Find all live events (ongoing)
      final liveEventsList = todayEventsList.where((event) {
        final status = (event['status'] as String? ?? '').toLowerCase();
        return status == 'ongoing';
      }).toList()
        ..sort((a, b) {
          final timeA = a['start_datetime'] as String? ?? '';
          final timeB = b['start_datetime'] as String? ?? '';
          return timeA.compareTo(timeB);
        });

      if (mounted) {
        setState(() {
          todayEvents = limitedEvents;
          totalTodayEvents = todayEventsList.length; // Store total count
          liveEvents = liveEventsList;
          loadingEvents = false;
        });
      }
    } catch (e) {
      print("Error loading today's events: $e");
      if (mounted) {
        setState(() {
          loadingEvents = false;
          if (!silent) {
            todayEvents = []; // Clear on error only if not silent
            totalTodayEvents = 0; // Reset count on error only if not silent
          }
        });
        // Show error only if not silent refresh
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to load events: ${e.toString()}"),
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

  Future<void> _openGoogleMaps(String location) async {
    try {
      final encodedLocation = Uri.encodeComponent(location);
      final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedLocation');
      
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not open Google Maps"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error opening Google Maps: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openWhatsApp(String joinInfo) async {
    try {
      Uri whatsappUrl;
      final cleanInfo = joinInfo.trim();
      if (RegExp(r'^\+?[0-9]{10,}$').hasMatch(cleanInfo)) {
        final phoneNumber = cleanInfo.replaceAll(RegExp(r'[^\d]'), '');
        whatsappUrl = Uri.parse('https://wa.me/$phoneNumber');
      } else if (cleanInfo.startsWith('http://') || cleanInfo.startsWith('https://')) {
        whatsappUrl = Uri.parse(cleanInfo);
      } else if (cleanInfo.startsWith('wa.me/') || cleanInfo.startsWith('chat.whatsapp.com/')) {
        whatsappUrl = Uri.parse('https://$cleanInfo');
      } else {
        final phoneMatch = RegExp(r'\+?[0-9]{10,}').firstMatch(cleanInfo);
        if (phoneMatch != null) {
          final phoneNumber = phoneMatch.group(0)!.replaceAll(RegExp(r'[^\d]'), '');
          whatsappUrl = Uri.parse('https://wa.me/$phoneNumber');
        } else {
          throw Exception("Invalid WhatsApp join information format");
        }
      }
      
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not open WhatsApp"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error opening WhatsApp: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
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

                  // LIVE NOW Section
                  _buildLiveNowCard(),

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

  Widget _buildLiveNowCard() {
    // Combine live prayers and live events
    final hasLiveContent = livePrayers.isNotEmpty || liveEvents.isNotEmpty;
    
    if (!hasLiveContent) {
      return const SizedBox.shrink(); // Don't show anything if no live content
    }

    // Separate offline and online prayers
    final offlinePrayers = livePrayers.where((prayer) {
      final prayerType = (prayer['prayer_type'] as String? ?? 'offline').toLowerCase();
      return prayerType == 'offline';
    }).toList();
    
    final onlinePrayers = livePrayers.where((prayer) {
      final prayerType = (prayer['prayer_type'] as String? ?? 'offline').toLowerCase();
      return prayerType == 'online';
    }).toList();

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
        // Priority order: Events (top) -> Offline Prayers (medium) -> Online Prayers (medium)
        ...liveEvents.map((event) => _buildSingleLiveEventCard(event)),
        ...offlinePrayers.map((prayer) => _buildSingleLivePrayerCard(prayer)),
        ...onlinePrayers.map((prayer) => _buildSingleLivePrayerCard(prayer)),
      ],
    );
  }

  Widget _buildSingleLivePrayerCard(Map<String, dynamic> prayer) {
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
    final startStr = prayer['start_datetime'] as String?;
    final endStr = prayer['end_datetime'] as String?;
    final prayerType = (prayer['prayer_type'] as String? ?? 'offline').toLowerCase();
    final location = prayer['location'] as String?;
    final joinInfo = prayer['join_info'] as String?;
    final prayerOccurrenceId = prayer['id'] as int?;

    String timeDisplay = "TBD";
    if (startStr != null && endStr != null) {
      try {
        final start = DateTime.parse(startStr).toLocal();
        final end = DateTime.parse(endStr).toLocal();
        if (start.year == end.year && start.month == end.month && start.day == end.day) {
          // Same day
          timeDisplay = "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}";
        } else {
          // Multi-day
          timeDisplay = "${DateFormat('MMM d, h:mm a').format(start)} - ${DateFormat('MMM d, h:mm a').format(end)}";
        }
      } catch (e) {
        timeDisplay = "$startStr - $endStr";
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[400]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PrayerDetailsScreen(
                prayer: prayer,
                onPrayerUpdated: () {
                  _loadTodayPrayers();
                },
                onPrayerDeleted: () {
                  _loadTodayPrayers();
                },
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.favorite, color: Colors.red, size: 28),
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
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
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const Text(
                                    'LIVE NOW',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Prayer Type Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: prayerType == 'online' ? Colors.green[50] : Colors.orange[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: prayerType == 'online' ? Colors.green[300]! : Colors.orange[300]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                prayerType == 'online' ? Icons.chat : Icons.location_on,
                                size: 12,
                                color: prayerType == 'online' ? Colors.green[700] : Colors.orange[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                prayerType == 'online' ? 'Online Prayer' : 'Offline Prayer',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: prayerType == 'online' ? Colors.green[700] : Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 6),
                            Text(
                              timeDisplay,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // CTA based on prayer type
              if (prayerType == 'online' && joinInfo != null && joinInfo.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openWhatsApp(joinInfo),
                    icon: const Icon(Icons.chat, size: 20),
                    label: const Text(
                      "JOIN NOW",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              else if (prayerType == 'offline' && location != null && location.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 18, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Happening at $location",
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.red[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openGoogleMaps(location),
                        icon: const Icon(Icons.map),
                        label: const Text("Open in Google Maps"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                          side: BorderSide(color: Colors.blue[700]!),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleLiveEventCard(Map<String, dynamic> event) {
    final title = event['title'] as String? ?? 'Event';
    final startStr = event['start_datetime'] as String?;
    final endStr = event['end_datetime'] as String?;
    final location = event['location'] as String?;
    final eventOccurrenceId = event['id'] as int?;

    String timeDisplay = "TBD";
    if (startStr != null && endStr != null) {
      try {
        final start = DateTime.parse(startStr).toLocal();
        final end = DateTime.parse(endStr).toLocal();
        if (start.year == end.year && start.month == end.month && start.day == end.day) {
          // Same day
          timeDisplay = "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}";
        } else {
          // Multi-day
          timeDisplay = "${DateFormat('MMM d, h:mm a').format(start)} - ${DateFormat('MMM d, h:mm a').format(end)}";
        }
      } catch (e) {
        timeDisplay = "$startStr - $endStr";
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[400]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventDetailsScreen(
                event: event,
                onEventUpdated: () {
                  _loadTodayEvents();
                },
                onEventDeleted: () {
                  _loadTodayEvents();
                },
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event, color: Colors.red, size: 28),
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
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
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const Text(
                                    'LIVE NOW',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 6),
                            Text(
                              timeDisplay,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (location != null && location.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 18, color: Colors.orange[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Event at $location',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w600,
                                  ),
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
              if (location != null && location.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openGoogleMaps(location),
                    icon: const Icon(Icons.map),
                    label: const Text("Open in Google Maps"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      side: BorderSide(color: Colors.blue[700]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
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
              "Today's Prayers",
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
                        // Filter out live prayers (they're shown in LIVE NOW section)
                        ...() {
                          final filteredPrayers = todayPrayers.where((prayer) {
                            final status = (prayer['status'] as String? ?? '').toLowerCase();
                            return status != 'ongoing';
                          }).toList();
                          return filteredPrayers.asMap().entries.map((entry) {
                            final index = entry.key;
                            return Column(
                              children: [
                                if (index > 0) const Divider(height: 24),
                                _buildPrayerScheduleItem(entry.value),
                              ],
                            );
                          }).toList();
                        }(),
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
    final title = prayer['title'] as String? ?? 'Prayer';
    final startStr = prayer['start_datetime'] as String?;
    final endStr = prayer['end_datetime'] as String?;
    final status = (prayer['status'] as String? ?? 'upcoming').toLowerCase();
    final prayerType = (prayer['prayer_type'] as String? ?? 'offline').toLowerCase();
    final location = prayer['location'] as String?;
    final joinInfo = prayer['join_info'] as String?;
    
    String timeDisplay = "TBD";
    if (startStr != null && endStr != null) {
      try {
        final start = DateTime.parse(startStr).toLocal();
        final end = DateTime.parse(endStr).toLocal();
        if (start.year == end.year && start.month == end.month && start.day == end.day) {
          // Same day
          timeDisplay = "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}";
        } else {
          // Multi-day
          timeDisplay = "${DateFormat('MMM d, h:mm a').format(start)} - ${DateFormat('MMM d, h:mm a').format(end)}";
        }
      } catch (e) {
        timeDisplay = "$startStr - $endStr";
      }
    }

    // Determine location display based on prayer type
    String locationDisplay;
    if (prayerType == 'online') {
      locationDisplay = "Join via WhatsApp";
    } else {
      locationDisplay = location ?? "Location TBD";
    }

    return _buildScheduleItem(
      icon: Icons.favorite,
      title: title,
      time: timeDisplay,
      location: locationDisplay,
      status: status,
      prayerType: prayerType,
      prayer: prayer, // Pass prayer data for navigation
    );
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

  Widget _buildUpcomingEvents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Events",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (loadingEvents)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadTodayEvents,
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
          child: loadingEvents
              ? const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              : todayEvents.isEmpty
                  ? _buildEmptyEventsState()
                  : Column(
                      children: [
                        // Filter out live events (they're shown in LIVE NOW section)
                        ...() {
                          final filteredEvents = todayEvents.where((event) {
                            final status = (event['status'] as String? ?? '').toLowerCase();
                            return status != 'ongoing';
                          }).toList();
                          return filteredEvents.asMap().entries.map((entry) {
                            final index = entry.key;
                            return Column(
                              children: [
                                if (index > 0) const Divider(height: 24),
                                _buildEventScheduleItem(entry.value),
                              ],
                            );
                          }).toList();
                        }(),
                        // Show "View All" if there are more than 5 events
                        if (totalTodayEvents > 5)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: TextButton.icon(
                              onPressed: () {
                                widget.onNavigateToTab?.call(1); // Navigate to Events tab to see all
                              },
                              icon: const Icon(Icons.arrow_forward, size: 18),
                              label: Text("View All (${totalTodayEvents} total)"),
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

  Widget _buildEventScheduleItem(Map<String, dynamic> event) {
    final title = event['title'] as String? ?? 'Event';
    final startStr = event['start_datetime'] as String?;
    final endStr = event['end_datetime'] as String?;
    final status = (event['status'] as String? ?? 'upcoming').toLowerCase();
    final location = event['location'] as String?;
    
    String timeDisplay = "TBD";
    if (startStr != null && endStr != null) {
      try {
        final start = DateTime.parse(startStr).toLocal();
        final end = DateTime.parse(endStr).toLocal();
        if (start.year == end.year && start.month == end.month && start.day == end.day) {
          // Same day
          timeDisplay = "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}";
        } else {
          // Multi-day
          timeDisplay = "${DateFormat('MMM d, h:mm a').format(start)} - ${DateFormat('MMM d, h:mm a').format(end)}";
        }
      } catch (e) {
        timeDisplay = "$startStr - $endStr";
      }
    }

    return _buildScheduleItem(
      icon: Icons.event,
      title: title,
      time: timeDisplay,
      location: location ?? "Location TBD",
      status: status,
      prayerType: 'offline', // Events are offline only
      prayer: event, // Pass event data for navigation
    );
  }

  Widget _buildEmptyEventsState() {
    return Padding(
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
            "No events scheduled today",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Create an event to get started",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
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
    String? prayerType,
    Map<String, dynamic>? prayer, // Can be prayer or event data for navigation
  }) {
    // Determine if it's an event (has event_type) or prayer (has prayer_type)
    final isEvent = prayer != null && prayer.containsKey('event_type');
    
    // Determine icon color based on status
    Color iconColor;
    Color iconBgColor;
    
    if (status == 'ongoing') {
      // Live Now - Red
      iconColor = Colors.red[700]!;
      iconBgColor = Colors.red[50]!;
    } else if (status == 'completed') {
      // Past - Grey
      iconColor = Colors.grey[600]!;
      iconBgColor = Colors.grey[200]!;
    } else {
      // Today (upcoming but happening today) - Orange
      // Since these are "Today's" items, they're either ongoing or today (not future)
      iconColor = Colors.orange[700]!;
      iconBgColor = Colors.orange[50]!;
    }
    
    return InkWell(
      onTap: prayer != null
          ? () {
              if (isEvent) {
                // Navigate to Event Details
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailsScreen(
                      event: prayer,
                      onEventUpdated: () {
                        _loadTodayEvents();
                      },
                      onEventDeleted: () {
                        _loadTodayEvents();
                      },
                    ),
                  ),
                );
              } else {
                // Navigate to Prayer Details
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrayerDetailsScreen(
                      prayer: prayer,
                      onPrayerUpdated: () {
                        _loadTodayPrayers();
                      },
                      onPrayerDeleted: () {
                        _loadTodayPrayers();
                      },
                    ),
                  ),
                );
              }
            }
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 24),
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
                  if (status != null) ...[
                    const SizedBox(width: 8),
                    isEvent ? _buildEventStatusTag(status) : _buildStatusTag(status),
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
                  // Show location icon for offline, chat icon for online
                  if (prayerType == 'offline') ...[
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
                  ] else if (prayerType == 'online') ...[
                    const SizedBox(width: 16),
                    Icon(Icons.chat, size: 14, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location, // This will be "Join via WhatsApp"
                        style: TextStyle(fontSize: 14, color: Colors.green[600], fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
      ),
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
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateEventScreen(
                        onEventCreated: () {
                          // Refresh events after creating
                          _loadTodayEvents();
                          // Navigate to Events tab when event is created
                          widget.onNavigateToTab?.call(1);
                        },
                      ),
                    ),
                  );
                  // Refresh events when returning from Create Event screen
                  _loadTodayEvents();
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

