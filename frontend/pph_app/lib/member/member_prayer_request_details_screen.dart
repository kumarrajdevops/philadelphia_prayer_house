import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/engagement_service.dart';

class MemberPrayerRequestDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  const MemberPrayerRequestDetailsScreen({
    super.key,
    required this.request,
  });

  @override
  State<MemberPrayerRequestDetailsScreen> createState() => _MemberPrayerRequestDetailsScreenState();
}

class _MemberPrayerRequestDetailsScreenState extends State<MemberPrayerRequestDetailsScreen> {
  Map<String, dynamic>? _request;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _loadRequest();
  }

  Future<void> _loadRequest() async {
    final requestId = _request?['id'] as int?;
    if (requestId == null) return;

    setState(() => _loading = true);

    try {
      final updatedRequest = await EngagementService.getPrayerRequestById(requestId);
      if (updatedRequest != null && mounted) {
        setState(() {
          _request = updatedRequest;
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load prayer request: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return Colors.blue;
      case 'prayed':
        return Colors.green;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return 'Submitted';
      case 'prayed':
        return 'Prayed For';
      case 'archived':
        return 'Archived';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Icons.send;
      case 'prayed':
        return Icons.check_circle;
      case 'archived':
        return Icons.archive;
      default:
        return Icons.info;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Unknown date";
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM d, y • h:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_request == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Prayer Request"),
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text("Prayer request not found"),
        ),
      );
    }

    final status = (_request!['status'] as String? ?? 'submitted').toLowerCase();
    final requestText = _request!['request_text'] as String? ?? '';
    final requestType = (_request!['request_type'] as String? ?? 'public').toLowerCase();
    final created_at = _request!['created_at'] as String?;
    final updated_at = _request!['updated_at'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Prayer Request Details"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequest,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRequest,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(status).withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getStatusIcon(status),
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getStatusLabel(status),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(status),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getStatusDescription(status),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Request Text
                    Text(
                      "Your Prayer Request",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        requestText,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Details Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Request Details",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            Icons.calendar_today,
                            "Submitted",
                            _formatDate(created_at),
                          ),
                          if (updated_at != null && updated_at != created_at) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              Icons.update,
                              "Last Updated",
                              _formatDate(updated_at),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            requestType == "private" ? Icons.lock : Icons.public,
                            "Prayer Type",
                            requestType == "private" 
                              ? "Private Prayer (One-on-one, never mentioned publicly)" 
                              : "Public Prayer (May be mentioned in church/group prayer)",
                          ),
                        ],
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline, color: Colors.amber[800], size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _getStatusInfo(status),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.amber[900],
                                height: 1.5,
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
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blue[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue[900],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return 'Your request is waiting to be reviewed by the pastor';
      case 'prayed':
        return 'The pastor has prayed for your request';
      case 'archived':
        return 'This request has been archived';
      default:
        return 'Unknown status';
    }
  }

  String _getStatusInfo(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return 'Your prayer request has been submitted and is waiting for the pastor to review it. You will receive an acknowledgement when your prayer has been prayed for.';
      case 'prayed':
        return 'Great news! The pastor has prayed for your request. Thank you for sharing your prayer need with us.';
      case 'archived':
        return 'Your prayer request has been prayed for and archived. May God give you strength and peace. If you have a new prayer need, please submit a new request.';
      default:
        return 'Your prayer request is being processed.';
    }
  }
}
