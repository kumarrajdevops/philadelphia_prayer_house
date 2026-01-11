import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/login_screen.dart';
import '../auth/auth_service.dart';
import '../services/prayer_service.dart';
import 'member_prayer_details_screen.dart';
import 'member_schedule_screen.dart';

class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> with WidgetsBindingObserver {
  String? memberName;
  bool _loading = true;
  List<Map<String, dynamic>> _todayPrayers = [];
  List<Map<String, dynamic>> _livePrayers = [];
  Timer? _refreshTimer;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMemberInfo();
    _loadTodayPrayers();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadTodayPrayers(); // Force refresh when app comes to foreground
    } else if (state == AppLifecycleState.paused) {
      _refreshTimer?.cancel(); // Stop timer when app goes to background
    } else if (state == AppLifecycleState.inactive) {
      _refreshTimer?.cancel();
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) {
        _loadTodayPrayers(silent: true);
      }
    });
  }

  Future<void> _loadMemberInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      memberName = prefs.getString("name") ?? prefs.getString("username") ?? "Member";
    });
  }

  Future<void> _loadTodayPrayers({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }

    try {
      final prayers = await PrayerService.getAllPrayers();
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      if (mounted) {
        final todayList = prayers.where((prayer) {
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

        // Find all live prayers
        final livePrayers = todayList.where((p) {
          return (p['status'] as String? ?? 'upcoming').toLowerCase() == 'inprogress';
        }).toList()
          ..sort((a, b) {
            // Sort by start time (earliest first)
            final timeA = a['start_time'] as String? ?? '';
            final timeB = b['start_time'] as String? ?? '';
            return timeA.compareTo(timeB);
          });

        setState(() {
          _todayPrayers = todayList;
          _livePrayers = livePrayers;
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
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

  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${_getGreeting()}, ${memberName ?? 'Member'}",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Welcome to Philadelphia Prayer House",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveNowCard() {
    // If there are live prayers, show them
    if (_livePrayers.isNotEmpty) {
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
          ..._livePrayers.map((prayer) => _buildSingleLivePrayerCard(prayer)),
        ],
      );
    }

    // If no live prayers, show Verse of the Day
    return _buildVerseOfTheDay();
  }

  Widget _buildVerseOfTheDay() {
    // Inspirational Bible verses
    final verses = [
      {
        'verse': 'Be still, and know that I am God.',
        'reference': 'Psalm 46:10',
      },
      {
        'verse': 'For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future.',
        'reference': 'Jeremiah 29:11',
      },
      {
        'verse': 'Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.',
        'reference': 'Philippians 4:6',
      },
      {
        'verse': 'The Lord is my shepherd, I lack nothing.',
        'reference': 'Psalm 23:1',
      },
      {
        'verse': 'Cast all your anxiety on him because he cares for you.',
        'reference': '1 Peter 5:7',
      },
      {
        'verse': 'I can do all this through him who gives me strength.',
        'reference': 'Philippians 4:13',
      },
      {
        'verse': 'Trust in the Lord with all your heart and lean not on your own understanding.',
        'reference': 'Proverbs 3:5',
      },
      {
        'verse': 'Come to me, all you who are weary and burdened, and I will give you rest.',
        'reference': 'Matthew 11:28',
      },
      {
        'verse': 'The Lord will fight for you; you need only to be still.',
        'reference': 'Exodus 14:14',
      },
      {
        'verse': 'For where two or three gather in my name, there am I with them.',
        'reference': 'Matthew 18:20',
      },
      {
        'verse': 'But those who hope in the Lord will renew their strength. They will soar on wings like eagles.',
        'reference': 'Isaiah 40:31',
      },
      {
        'verse': 'The Lord is close to the brokenhearted and saves those who are crushed in spirit.',
        'reference': 'Psalm 34:18',
      },
    ];

    // Select a verse based on current day to vary it
    final now = DateTime.now();
    final verseIndex = now.day % verses.length;
    final selectedVerse = verses[verseIndex];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[400]!,
            Colors.purple[500]!,
            Colors.blue[600]!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'VERSE OF THE DAY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  selectedVerse['verse']!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                  ),
                  child: Text(
                    selectedVerse['reference']!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildSingleLivePrayerCard(Map<String, dynamic> prayer) {
    final title = prayer['title'] as String? ?? 'Prayer';
    final startTime = prayer['start_time'] as String?;
    final endTime = prayer['end_time'] as String?;
    final prayerType = (prayer['prayer_type'] as String? ?? 'offline').toLowerCase();
    final location = prayer['location'] as String?;
    final joinInfo = prayer['join_info'] as String?;

    String timeDisplay = "TBD";
    if (startTime != null && endTime != null) {
      timeDisplay = "${_formatTime(startTime)} - ${_formatTime(endTime)}";
    } else if (startTime != null) {
      timeDisplay = _formatTime(startTime);
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
              builder: (_) => MemberPrayerDetailsScreen(prayer: prayer),
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
                        const SizedBox(height: 4),
                        // Prayer type indicator
                        Row(
                          children: [
                            Icon(
                              prayerType == 'online' ? Icons.chat : Icons.location_on,
                              size: 16,
                              color: prayerType == 'online' ? Colors.green[700] : Colors.orange[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              prayerType == 'online' ? 'Online Prayer' : 'Offline Prayer',
                              style: TextStyle(
                                fontSize: 14,
                                color: prayerType == 'online' ? Colors.green[700] : Colors.orange[700],
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

  Widget _buildTodayPrayersList() {
    // Filter out live prayer from today's list
    final upcomingPrayers = _todayPrayers.where((prayer) {
      final status = (prayer['status'] as String? ?? 'upcoming').toLowerCase();
      return status == 'upcoming';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: const Text(
            "Today's Prayers",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (upcomingPrayers.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Icon(Icons.favorite_border, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  "No prayers scheduled for today.",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Please check back later.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...upcomingPrayers.map((prayer) => _buildPrayerCard(prayer)),
      ],
    );
  }

  Widget _buildPrayerCard(Map<String, dynamic> prayer) {
    final title = prayer['title'] as String? ?? 'Prayer';
    final startTime = prayer['start_time'] as String?;
    final endTime = prayer['end_time'] as String?;
    final prayerType = (prayer['prayer_type'] as String? ?? 'offline').toLowerCase();
    final location = prayer['location'] as String?;

    String timeDisplay = "TBD";
    if (startTime != null && endTime != null) {
      timeDisplay = "${_formatTime(startTime)} - ${_formatTime(endTime)}";
    } else if (startTime != null) {
      timeDisplay = _formatTime(startTime);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue[300]!, width: 1),
                            ),
                            child: const Text(
                              'UPCOMING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Actions",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MemberScheduleScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(Icons.schedule, color: Colors.blue[700], size: 32),
                              const SizedBox(height: 8),
                              const Text(
                                "Prayers",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      child: InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Events - Coming soon"),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(Icons.event, color: Colors.orange[700], size: 32),
                              const SizedBox(height: 8),
                              const Text(
                                "Events",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Bible - Coming soon"),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(Icons.book, color: Colors.purple[700], size: 32),
                              const SizedBox(height: 8),
                              const Text(
                                "Bible",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      child: InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Song Lyrics - Coming soon"),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(Icons.music_note, color: Colors.pink[700], size: 32),
                              const SizedBox(height: 8),
                              const Text(
                                "Song Lyrics",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Logout"),
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
                  child: Text(
                    (memberName != null && memberName!.isNotEmpty) 
                        ? memberName!.substring(0, 1).toUpperCase() 
                        : "M",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  memberName ?? "Member",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Member",
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Calendar - Coming soon")),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text("Help & Support"),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Help & Support - Coming soon")),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Settings"),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Settings - Coming soon")),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: const Text("Philadelphia Prayer House"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTodayPrayers,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreeting(),
                    _buildLiveNowCard(),
                    _buildTodayPrayersList(),
                    const SizedBox(height: 12),
                    _buildQuickActions(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MemberScheduleScreen(),
              ),
            ).then((_) {
              setState(() {
                _selectedIndex = 0; // Reset to Home
              });
              _loadTodayPrayers(); // Refresh when returning
            });
          } else if (index == 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Events - Coming soon")),
            );
            setState(() {
              _selectedIndex = 0; // Reset to Home
            });
          } else if (index == 3) {
            // Requests - prayer requests screen
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Requests - Coming soon")),
            );
            setState(() {
              _selectedIndex = 0; // Reset to Home
            });
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: 'Prayers',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.help_outline),
            selectedIcon: Icon(Icons.help),
            label: 'Requests',
          ),
        ],
      ),
    );
  }
}
