import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/engagement_service.dart';
import '../services/prayer_service.dart';
import '../services/event_service.dart';
import 'member_prayer_details_screen.dart';
import 'member_event_details_screen.dart';

class MemberFavoritesScreen extends StatefulWidget {
  const MemberFavoritesScreen({super.key});

  @override
  State<MemberFavoritesScreen> createState() => _MemberFavoritesScreenState();
}

class _MemberFavoritesScreenState extends State<MemberFavoritesScreen> {
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _favoritePrayers = [];
  List<Map<String, dynamic>> _favoriteEvents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);

    try {
      // Load user's favorites
      final favorites = await EngagementService.getFavorites();
      
      // Get prayer series IDs
      final prayerSeriesIds = favorites
          .where((f) => f['prayer_series_id'] != null)
          .map((f) => f['prayer_series_id'] as int)
          .toList();

      // Get event series IDs
      final eventSeriesIds = favorites
          .where((f) => f['event_series_id'] != null)
          .map((f) => f['event_series_id'] as int)
          .toList();

      // Load prayer occurrences and group by series
      final allPrayerOccurrences = await PrayerService.getPrayerOccurrences();
      Map<int, Map<String, dynamic>> prayerSeriesMap = {};
      for (final occurrence in allPrayerOccurrences) {
        final seriesId = occurrence['prayer_series_id'] as int?;
        if (seriesId != null && prayerSeriesIds.contains(seriesId)) {
          if (!prayerSeriesMap.containsKey(seriesId)) {
            prayerSeriesMap[seriesId] = {
              'id': seriesId,
              'title': occurrence['prayer_series_title'] as String? ?? occurrence['title'] as String? ?? 'Prayer',
              'description': occurrence['prayer_series_description'] as String?,
              'occurrences': <Map<String, dynamic>>[],
            };
          }
          (prayerSeriesMap[seriesId]!['occurrences'] as List).add(occurrence);
        }
      }

      // Load event occurrences and group by series
      final allEventOccurrences = await EventService.getEventOccurrences();
      Map<int, Map<String, dynamic>> eventSeriesMap = {};
      for (final occurrence in allEventOccurrences) {
        final seriesId = occurrence['event_series_id'] as int?;
        if (seriesId != null && eventSeriesIds.contains(seriesId)) {
          if (!eventSeriesMap.containsKey(seriesId)) {
            eventSeriesMap[seriesId] = {
              'id': seriesId,
              'title': occurrence['event_series_title'] as String? ?? occurrence['title'] as String? ?? 'Event',
              'description': occurrence['event_series_description'] as String?,
              'occurrences': <Map<String, dynamic>>[],
            };
          }
          (eventSeriesMap[seriesId]!['occurrences'] as List).add(occurrence);
        }
      }

      if (mounted) {
        setState(() {
          _favorites = favorites;
          _favoritePrayers = prayerSeriesMap.values.toList();
          _favoriteEvents = eventSeriesMap.values.toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load favorites: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeFavorite(int favoriteId, {int? prayerSeriesId, int? eventSeriesId}) async {
    try {
      final success = await EngagementService.removeFavorite(favoriteId);
      if (success && mounted) {
        // Remove from local lists
        setState(() {
          _favorites.removeWhere((f) => f['id'] == favoriteId);
          if (prayerSeriesId != null) {
            _favoritePrayers.removeWhere((p) => p['id'] == prayerSeriesId);
          }
          if (eventSeriesId != null) {
            _favoriteEvents.removeWhere((e) => e['id'] == eventSeriesId);
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Removed from favorites"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to remove favorite: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Favorites"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _favoritePrayers.isEmpty && _favoriteEvents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        "No favorites yet",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Tap the star icon on prayers or events to add them here",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_favoritePrayers.isNotEmpty) ...[
                          Text(
                            "Favorite Prayers",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._favoritePrayers.map((prayer) => _buildPrayerCard(prayer)),
                          const SizedBox(height: 24),
                        ],
                        if (_favoriteEvents.isNotEmpty) ...[
                          Text(
                            "Favorite Events",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._favoriteEvents.map((event) => _buildEventCard(event)),
                        ],
                      ],
                    ),
                  ),
                ),
      extendBody: true,
    );
  }

  Widget _buildPrayerCard(Map<String, dynamic> prayerSeries) {
    final favorite = _favorites.firstWhere(
      (f) => f['prayer_series_id'] == prayerSeries['id'],
      orElse: () => <String, dynamic>{},
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () async {
          // Navigate to the latest prayer occurrence for this series
          try {
            final occurrences = prayerSeries['occurrences'] as List<Map<String, dynamic>>?;
            if (occurrences != null && occurrences.isNotEmpty) {
              // Sort by start_datetime descending to get the latest
              occurrences.sort((a, b) {
                final dateA = a['start_datetime'] as String? ?? '';
                final dateB = b['start_datetime'] as String? ?? '';
                return dateB.compareTo(dateA);
              });
              
              final latestOccurrence = occurrences.first;
              if (mounted && latestOccurrence['id'] != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberPrayerDetailsScreen(
                      prayer: latestOccurrence,
                    ),
                  ),
                );
              }
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Failed to load prayer details: ${e.toString()}"),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.access_time, color: Colors.blue[700], size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prayerSeries['title'] as String? ?? 'Prayer',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (prayerSeries['description'] != null)
                      Text(
                        prayerSeries['description'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                onPressed: favorite.isNotEmpty && favorite['id'] != null
                    ? () => _removeFavorite(
                          favorite['id'] as int,
                          prayerSeriesId: prayerSeries['id'] as int,
                        )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> eventSeries) {
    final favorite = _favorites.firstWhere(
      (f) => f['event_series_id'] == eventSeries['id'],
      orElse: () => <String, dynamic>{},
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () async {
          // Navigate to the latest event occurrence for this series
          try {
            final occurrences = eventSeries['occurrences'] as List<Map<String, dynamic>>?;
            if (occurrences != null && occurrences.isNotEmpty) {
              // Sort by start_datetime descending to get the latest
              occurrences.sort((a, b) {
                final dateA = a['start_datetime'] as String? ?? '';
                final dateB = b['start_datetime'] as String? ?? '';
                return dateB.compareTo(dateA);
              });
              
              final latestOccurrence = occurrences.first;
              if (mounted && latestOccurrence['id'] != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberEventDetailsScreen(
                      event: latestOccurrence,
                    ),
                  ),
                );
              }
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Failed to load event details: ${e.toString()}"),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.event, color: Colors.orange[700], size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventSeries['title'] as String? ?? 'Event',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (eventSeries['description'] != null)
                      Text(
                        eventSeries['description'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                onPressed: favorite.isNotEmpty && favorite['id'] != null
                    ? () => _removeFavorite(
                          favorite['id'] as int,
                          eventSeriesId: eventSeries['id'] as int,
                        )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
