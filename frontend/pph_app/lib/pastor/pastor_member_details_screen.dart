import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/member_service.dart';
import '../services/engagement_service.dart';

class PastorMemberDetailsScreen extends StatefulWidget {
  final int memberId;

  const PastorMemberDetailsScreen({super.key, required this.memberId});

  @override
  State<PastorMemberDetailsScreen> createState() => _PastorMemberDetailsScreenState();
}

class _PastorMemberDetailsScreenState extends State<PastorMemberDetailsScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _member;
  List<Map<String, dynamic>> _prayerRequests = [];
  List<Map<String, dynamic>> _attendance = [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMemberDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMemberDetails() async {
    setState(() => _loading = true);
    try {
      final member = await MemberService.getMemberDetails(widget.memberId);
      if (member != null && mounted) {
        setState(() {
          _member = member;
          _loading = false;
        });
        _loadPrayerRequests();
        _loadAttendance();
      } else {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Member not found")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load member: $e")),
        );
      }
    }
  }

  Future<void> _loadPrayerRequests() async {
    try {
      final requests = await MemberService.getMemberPrayerRequests(widget.memberId);
      if (mounted) {
        setState(() => _prayerRequests = requests);
      }
    } catch (e) {
      print("Failed to load prayer requests: $e");
    }
  }

  Future<void> _loadAttendance() async {
    try {
      final attendance = await MemberService.getMemberAttendance(widget.memberId);
      if (mounted) {
        setState(() => _attendance = attendance);
      }
    } catch (e) {
      print("Failed to load attendance: $e");
    }
  }

  Future<void> _blockMember() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Block Member"),
        content: const Text("Are you sure you want to block this member? They will not be able to login."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Block"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await MemberService.blockMember(widget.memberId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Member blocked successfully")),
          );
          _loadMemberDetails();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to block member: $e")),
          );
        }
      }
    }
  }

  Future<void> _changeRole() async {
    if (_member == null) return;
    
    final currentRole = _member!["role"] ?? "member";
    final validRoles = ["member", "pastor", "admin"];
    
    // Show dialog to select new role
    final newRole = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Role"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Current role: ${currentRole.toUpperCase()}"),
            const SizedBox(height: 16),
            const Text("Select new role:"),
            const SizedBox(height: 12),
            ...validRoles.map((role) => RadioListTile<String>(
              title: Text(role.toUpperCase()),
              value: role,
              groupValue: currentRole,
              onChanged: (value) {
                if (value != null) {
                  Navigator.pop(context, value);
                }
              },
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
    
    if (newRole == null || newRole == currentRole) return;
    
    // Confirm role change
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Role Change"),
        content: Text(
          "Are you sure you want to change this member's role from ${currentRole.toUpperCase()} to ${newRole.toUpperCase()}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // Update role
    try {
      await MemberService.updateMember(widget.memberId, {"role": newRole});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Role changed to ${newRole.toUpperCase()}"),
            backgroundColor: Colors.green,
          ),
        );
        // Reload member details
        _loadMemberDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to change role: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unblockMember() async {
    try {
      await MemberService.unblockMember(widget.memberId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Member unblocked successfully")),
        );
        _loadMemberDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to unblock member: $e")),
        );
      }
    }
  }

  Widget _buildOverviewTab() {
    if (_member == null) return const SizedBox();

    final name = _member!["name"] ?? "Unknown";
    final username = _member!["username"] ?? "";
    final email = _member!["email"] ?? "";
    final phone = _member!["phone"] ?? "";
    final role = _member!["role"] ?? "member";
    final isActive = _member!["is_active"] ?? true;
    final isDeleted = _member!["is_deleted"] ?? false;
    final profileImageUrl = _member!["profile_image_url"];
    final emailVerified = _member!["email_verified"] ?? false;
    final lastLogin = _member!["last_login"];
    final createdAt = _member!["created_at"];
    final prayerRequestsCount = _member!["prayer_requests_count"] ?? 0;
    final attendanceCount = _member!["attendance_count"] ?? 0;
    final favoritesCount = _member!["favorites_count"] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue[700],
                    backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                        ? NetworkImage("${Uri.parse("http://10.0.2.2:8000")}/uploads/$profileImageUrl")
                        : null,
                    child: profileImageUrl == null || profileImageUrl.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : "M",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (username.isNotEmpty) Text("@$username"),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: role == "pastor" || role == "admin"
                                    ? Colors.orange[100]
                                    : Colors.blue[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: role == "pastor" || role == "admin"
                                      ? Colors.orange[900]
                                      : Colors.blue[900],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isDeleted
                                  ? Icons.delete_outline
                                  : isActive
                                      ? Icons.check_circle
                                      : Icons.block,
                              color: isDeleted
                                  ? Colors.grey
                                  : isActive
                                      ? Colors.green
                                      : Colors.red,
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard("Prayer Requests", prayerRequestsCount.toString(), Icons.favorite),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard("Attendance", attendanceCount.toString(), Icons.event_available),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard("Favorites", favoritesCount.toString(), Icons.favorite),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Contact info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Contact Information",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (email.isNotEmpty)
                    _buildInfoRow(Icons.email, "Email", email, emailVerified),
                  if (phone.isNotEmpty)
                    _buildInfoRow(Icons.phone, "Phone", phone, null),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Account info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Account Information",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (createdAt != null)
                    _buildInfoRow(
                      Icons.calendar_today,
                      "Registered",
                      DateFormat("MMM dd, yyyy").format(DateTime.parse(createdAt)),
                      null,
                    ),
                  if (lastLogin != null)
                    _buildInfoRow(
                      Icons.access_time,
                      "Last Login",
                      DateFormat("MMM dd, yyyy HH:mm").format(DateTime.parse(lastLogin)),
                      null,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Role change
          if (!isDeleted)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Role",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoRow(
                            Icons.person,
                            "Current Role",
                            role.toUpperCase(),
                            null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _changeRole,
                          icon: const Icon(Icons.edit),
                          label: const Text("Change Role"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ),
          ),
          const SizedBox(height: 16),
          // Actions
          if (!isDeleted)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isActive ? _blockMember : _unblockMember,
                    icon: Icon(isActive ? Icons.block : Icons.check_circle),
                    label: Text(isActive ? "Block Member" : "Unblock Member"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.blue[700]),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool? verified) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
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
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: Text(value)),
                    if (verified != null)
                      Icon(
                        verified ? Icons.verified : Icons.verified_outlined,
                        size: 16,
                        color: verified ? Colors.green : Colors.grey,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerRequestsTab() {
    if (_prayerRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No prayer requests",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _prayerRequests.length,
      itemBuilder: (context, index) {
        final request = _prayerRequests[index];
        final requestType = request["request_type"] ?? "public";
        final status = request["status"] ?? "submitted";
        final requestText = request["request_text"] ?? "";
        final createdAt = request["created_at"];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              requestText.length > 100 ? "${requestText.substring(0, 100)}..." : requestText,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: requestType == "public" ? Colors.blue[100] : Colors.purple[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        requestType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: requestType == "public" ? Colors.blue[900] : Colors.purple[900],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == "prayed"
                            ? Colors.green[100]
                            : status == "archived"
                                ? Colors.grey[100]
                                : Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: status == "prayed"
                              ? Colors.green[900]
                              : status == "archived"
                                  ? Colors.grey[900]
                                  : Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    DateFormat("MMM dd, yyyy HH:mm").format(DateTime.parse(createdAt)),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceTab() {
    if (_attendance.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No attendance records",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _attendance.length,
      itemBuilder: (context, index) {
        final record = _attendance[index];
        final joinedAt = record["joined_at"];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text(
              record["prayer_occurrence_id"] != null
                  ? "Prayer Attendance"
                  : "Event Attendance",
            ),
            subtitle: joinedAt != null
                ? Text(
                    DateFormat("MMM dd, yyyy HH:mm").format(DateTime.parse(joinedAt)),
                    style: TextStyle(color: Colors.grey[600]),
                  )
                : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_member?["name"] ?? "Member Details"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Overview"),
            Tab(text: "Prayer Requests"),
            Tab(text: "Attendance"),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildPrayerRequestsTab(),
                _buildAttendanceTab(),
              ],
            ),
    );
  }
}
