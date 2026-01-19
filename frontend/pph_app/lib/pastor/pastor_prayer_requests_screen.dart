import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/engagement_service.dart';
import 'pastor_prayer_request_details_screen.dart';

class PastorPrayerRequestsScreen extends StatefulWidget {
  const PastorPrayerRequestsScreen({super.key});

  @override
  State<PastorPrayerRequestsScreen> createState() => _PastorPrayerRequestsScreenState();
}

class _PastorPrayerRequestsScreenState extends State<PastorPrayerRequestsScreen> {
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _filteredRequests = [];
  String _selectedFilter = "public"; // public, private, prayed, archived
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrayerRequests();
  }

  Future<void> _loadPrayerRequests() async {
    setState(() {
      _loading = true;
    });

    try {
      final requests = await EngagementService.getPrayerRequests();
      if (mounted) {
        setState(() {
          _allRequests = requests;
          _applyFilter();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load prayer requests: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilter() {
    if (_selectedFilter == "archived") {
      // "Archived" shows only archived requests
      _filteredRequests = _allRequests
          .where((request) => (request['status'] as String? ?? '').toLowerCase() == 'archived')
          .toList();
    } else {
      // All other filters exclude archived prayers
      final nonArchivedRequests = _allRequests.where((request) {
        final status = (request['status'] as String? ?? 'submitted').toLowerCase();
        return status != 'archived';
      }).toList();

      if (_selectedFilter == "public") {
        // "Public" shows all public (non-archived) requests
        _filteredRequests = nonArchivedRequests
            .where((request) => (request['request_type'] as String? ?? 'public').toLowerCase() == 'public')
            .toList();
      } else if (_selectedFilter == "private") {
        // "Private" shows all private (non-archived) requests
        _filteredRequests = nonArchivedRequests
            .where((request) => (request['request_type'] as String? ?? 'public').toLowerCase() == 'private')
            .toList();
      } else if (_selectedFilter == "prayed") {
        // "Prayed" shows prayed requests (non-archived)
        _filteredRequests = nonArchivedRequests
            .where((request) => (request['status'] as String? ?? 'submitted').toLowerCase() == 'prayed')
            .toList();
      } else {
        // Fallback: show all non-archived
        _filteredRequests = nonArchivedRequests;
      }
    }
    
    // Sort by latest timestamp (newest first)
    // Priority: prayed_at > archived_at > created_at
    _filteredRequests.sort((a, b) {
      DateTime? getLatestTimestamp(Map<String, dynamic> request) {
        final prayedAt = request['prayed_at'] as String?;
        final archivedAt = request['archived_at'] as String?;
        final createdAt = request['created_at'] as String?;
        
        try {
          if (prayedAt != null && prayedAt.isNotEmpty) {
            return DateTime.parse(prayedAt);
          }
          if (archivedAt != null && archivedAt.isNotEmpty) {
            return DateTime.parse(archivedAt);
          }
          if (createdAt != null && createdAt.isNotEmpty) {
            return DateTime.parse(createdAt);
          }
        } catch (e) {
          // If parsing fails, return null
        }
        return null;
      }
      
      final timestampA = getLatestTimestamp(a);
      final timestampB = getLatestTimestamp(b);
      
      if (timestampA == null && timestampB == null) return 0;
      if (timestampA == null) return 1; // nulls go to end
      if (timestampB == null) return -1; // nulls go to end
      
      return timestampB.compareTo(timestampA); // Newest first
    });
  }

  Future<void> _updateRequestStatus(int requestId, String status) async {
    try {
      final success = await EngagementService.updatePrayerRequestStatus(requestId, status);
      if (success && mounted) {
        // Reload requests
        await _loadPrayerRequests();
        if (status == 'prayed') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Prayer request marked as prayed and archived. Member will receive acknowledgement."),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Prayer request marked as ${status}"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to update prayer request status"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Colors.blue;
      case 'prayed':
        return Colors.green;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Unknown date";
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return "Just now";
          }
          return "${difference.inMinutes}m ago";
        }
        return "${difference.inHours}h ago";
      } else if (difference.inDays == 1) {
        return "Yesterday";
      } else if (difference.inDays < 7) {
        return "${difference.inDays}d ago";
      } else {
        return DateFormat('MMM d, y').format(date);
      }
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Prayer Requests"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPrayerRequests,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip("public", "Public", _allRequests.where((r) {
                          final status = (r['status'] as String? ?? '').toLowerCase();
                          final requestType = (r['request_type'] as String? ?? 'public').toLowerCase();
                          return status != 'archived' && requestType == 'public';
                        }).length),
                        const SizedBox(width: 8),
                        _buildFilterChip("private", "Private", _allRequests.where((r) {
                          final status = (r['status'] as String? ?? '').toLowerCase();
                          final requestType = (r['request_type'] as String? ?? 'public').toLowerCase();
                          return status != 'archived' && requestType == 'private';
                        }).length),
                        const SizedBox(width: 8),
                        _buildFilterChip("prayed", "Prayed", _allRequests.where((r) {
                          final status = (r['status'] as String? ?? '').toLowerCase();
                          return status == 'prayed' && status != 'archived';
                        }).length),
                        const SizedBox(width: 8),
                        _buildFilterChip("archived", "Archived", _allRequests.where((r) => (r['status'] as String? ?? '').toLowerCase() == 'archived').length),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Requests List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRequests.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadPrayerRequests,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredRequests.length,
                          itemBuilder: (context, index) {
                            final request = _filteredRequests[index];
                            return _buildRequestCard(request);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, int count) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.3) : Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
            _applyFilter();
          });
        }
      },
      selectedColor: Colors.blue[700],
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[800],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final id = request['id'] as int? ?? 0;
    final requestText = request['request_text'] as String? ?? '';
    final status = (request['status'] as String? ?? 'submitted').toLowerCase();
    final requestType = (request['request_type'] as String? ?? 'public').toLowerCase();
    final created_at = request['created_at'] as String?;
    final displayName = request['display_name'] as String? ?? 'Unknown';
    final username = request['username'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(status).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PastorPrayerRequestDetailsScreen(request: request),
            ),
          ).then((_) => _loadPrayerRequests()); // Refresh after returning
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Member Info Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                        if (username != null)
                          Text(
                            "@$username",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Request Type Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: requestType == "private" ? Colors.orange[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          requestType == "private" ? Icons.lock : Icons.public,
                          size: 14,
                          color: requestType == "private" ? Colors.orange[700] : Colors.green[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          requestType == "private" ? "Private" : "Public",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: requestType == "private" ? Colors.orange[700] : Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Status Badge and Date Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getStatusColor(status), width: 1),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(created_at),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Request Text (truncated preview)
            Text(
              requestText.length > 150 ? '${requestText.substring(0, 150)}...' : requestText,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            // Tap to view details hint
            Row(
              children: [
                Text(
                  "Tap to view full details",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: Colors.blue[700], size: 20),
              ],
            ),
            const SizedBox(height: 16),
            // Action Buttons (quick action)
            if (status == 'submitted')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _updateRequestStatus(id, 'prayed'),
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: const Text("Mark as Prayed"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            if (status == 'archived')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.archive, color: Colors.grey[600], size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "This request has been archived",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;
    if (_selectedFilter == "public") {
      message = "No public prayer requests";
      icon = Icons.public;
    } else if (_selectedFilter == "private") {
      message = "No private prayer requests";
      icon = Icons.lock;
    } else if (_selectedFilter == "prayed") {
      message = "No prayed requests yet";
      icon = Icons.check_circle_outline;
    } else if (_selectedFilter == "archived") {
      message = "No archived requests";
      icon = Icons.archive_outlined;
    } else {
      message = "No prayer requests yet";
      icon = Icons.favorite_border;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
