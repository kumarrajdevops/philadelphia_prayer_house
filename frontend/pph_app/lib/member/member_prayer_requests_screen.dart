import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/engagement_service.dart';
import 'member_prayer_request_details_screen.dart';

class MemberPrayerRequestsScreen extends StatefulWidget {
  const MemberPrayerRequestsScreen({super.key});

  @override
  State<MemberPrayerRequestsScreen> createState() => _MemberPrayerRequestsScreenState();
}

class _MemberPrayerRequestsScreenState extends State<MemberPrayerRequestsScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _requestController = TextEditingController();
  String _requestType = "public"; // "public" or "private"
  bool _isSubmitting = false;
  
  late TabController _tabController;
  List<Map<String, dynamic>> _myRequests = [];
  bool _loadingRequests = false;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    _loadMyRequests();
  }

  @override
  void dispose() {
    _requestController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyRequests() async {
    setState(() => _loadingRequests = true);
    try {
      final requests = await EngagementService.getMyPrayerRequests(context: context);
      if (mounted) {
        setState(() {
          _myRequests = requests;
          _sortRequests();
          _loadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingRequests = false);
      }
    }
  }

  void _sortRequests() {
    // Sort by latest timestamp (newest first)
    // Priority: prayed_at > archived_at > created_at
    _myRequests.sort((a, b) {
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

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await EngagementService.submitPrayerRequest(
        requestText: _requestController.text.trim(),
        requestType: _requestType,
      );

      if (result != null && mounted) {
        // Clear form
        _requestController.clear();
        setState(() {
          _requestType = "public";
        });

        // Reload requests list
        await _loadMyRequests();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Prayer request submitted successfully"),
            backgroundColor: Colors.green,
          ),
        );
        
        // Switch to "My Requests" tab to show the new request
        _tabController.animateTo(1);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to submit prayer request. Please try again."),
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
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
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

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final id = request['id'] as int? ?? 0;
    final requestText = request['request_text'] as String? ?? '';
    final status = (request['status'] as String? ?? 'submitted').toLowerCase();
    final requestType = (request['request_type'] as String? ?? 'public').toLowerCase();
    final created_at = request['created_at'] as String?;

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
              builder: (_) => MemberPrayerRequestDetailsScreen(request: request),
            ),
          ).then((_) => _loadMyRequests()); // Refresh after returning
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Request Type Badge Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Prayer Request",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Prayer Requests"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Submit Request"),
            Tab(text: "My Requests"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Submit Tab
          SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.favorite, size: 48, color: Colors.blue[700]),
                    const SizedBox(height: 12),
                    Text(
                      "Share Your Prayer Request",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Submit your prayer request below. Our pastor will pray for you.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Prayer Request Text Field
              Text(
                "Your Prayer Request",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _requestController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: "Share your prayer request here...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter your prayer request";
                  }
                  if (value.trim().length < 10) {
                    return "Please provide more details (at least 10 characters)";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Prayer Type Selection
              Text(
                "Prayer Type",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _requestType = "public";
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _requestType == "public" ? Colors.blue[50] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _requestType == "public" ? Colors.blue[700]! : Colors.grey[300]!,
                            width: _requestType == "public" ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.public,
                                  color: _requestType == "public" ? Colors.blue[700] : Colors.grey[600],
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Public Prayer",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _requestType == "public" ? Colors.blue[900] : Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Can be mentioned in church/group prayer. Your name may be shared.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _requestType = "private";
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _requestType == "private" ? Colors.blue[50] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _requestType == "private" ? Colors.blue[700]! : Colors.grey[300]!,
                            width: _requestType == "private" ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lock,
                                  color: _requestType == "private" ? Colors.blue[700] : Colors.grey[600],
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Private Prayer",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _requestType == "private" ? Colors.blue[900] : Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "One-on-one prayer only. Never mentioned publicly. Your identity is protected.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        "Submit Prayer Request",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              // Info Note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber[800], size: 24),
                    const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Your prayer request will be reviewed by the pastor. You'll receive an acknowledgement when your prayer has been prayed for.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber[900],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
          ),
          // My Requests Tab
          _loadingRequests
              ? const Center(child: CircularProgressIndicator())
              : _myRequests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            "No prayer requests yet",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              "Submit your first prayer request using the 'Submit Request' tab",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadMyRequests,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _myRequests.length,
                        itemBuilder: (context, index) {
                          return _buildRequestCard(_myRequests[index]);
                        },
                      ),
                    ),
        ],
      ),
      extendBody: true,
    );
  }
}
