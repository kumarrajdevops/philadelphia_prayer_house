import 'package:flutter/material.dart';
import '../services/member_service.dart';
import 'pastor_member_details_screen.dart';

class PastorMembersScreen extends StatefulWidget {
  const PastorMembersScreen({super.key});

  @override
  State<PastorMembersScreen> createState() => _PastorMembersScreenState();
}

class _PastorMembersScreenState extends State<PastorMembersScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  String _searchQuery = "";
  String? _selectedRole;
  bool? _selectedStatus; // true = active, false = blocked, null = all

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    try {
      final members = await MemberService.getMembers(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        role: _selectedRole,
        isActive: _selectedStatus,
      );
      if (mounted) {
        setState(() {
          _members = members;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load members: $e")),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _loadMembers();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Filter Members"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: "Role",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text("All Roles")),
                DropdownMenuItem(value: "member", child: Text("Member")),
                DropdownMenuItem(value: "pastor", child: Text("Pastor")),
                DropdownMenuItem(value: "admin", child: Text("Admin")),
              ],
              onChanged: (value) {
                setState(() => _selectedRole = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<bool?>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: "Status",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text("All Status")),
                DropdownMenuItem(value: true, child: Text("Active")),
                DropdownMenuItem(value: false, child: Text("Blocked")),
              ],
              onChanged: (value) {
                setState(() => _selectedStatus = value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedRole = null;
                _selectedStatus = null;
              });
            },
            child: const Text("Clear"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadMembers();
            },
            child: const Text("Apply"),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final name = member["name"] ?? "Unknown";
    final username = member["username"] ?? "";
    final email = member["email"] ?? "";
    final phone = member["phone"] ?? "";
    final role = member["role"] ?? "member";
    final isActive = member["is_active"] ?? true;
    final isDeleted = member["is_deleted"] ?? false;
    final profileImageUrl = member["profile_image_url"];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.blue[700],
          backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
              ? NetworkImage("${Uri.parse("http://10.0.2.2:8000")}/uploads/$profileImageUrl")
              : null,
          child: profileImageUrl == null || profileImageUrl.isEmpty
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : "M",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (username.isNotEmpty) Text("@$username"),
            if (email.isNotEmpty) Text(email),
            if (phone.isNotEmpty) Text(phone),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Role badge
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
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: role == "pastor" || role == "admin"
                      ? Colors.orange[900]
                      : Colors.blue[900],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Status indicator
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
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PastorMemberDetailsScreen(memberId: member["id"]),
            ),
          ).then((_) => _loadMembers()); // Refresh after returning
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Members"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: "Filter",
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by name, username, phone, or email...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged("");
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          // Filter chips
          if (_selectedRole != null || _selectedStatus != null)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_selectedRole != null)
                    Chip(
                      label: Text("Role: ${_selectedRole!}"),
                      onDeleted: () {
                        setState(() => _selectedRole = null);
                        _loadMembers();
                      },
                    ),
                  if (_selectedStatus != null)
                    Chip(
                      label: Text(
                        _selectedStatus! ? "Active" : "Blocked",
                      ),
                      onDeleted: () {
                        setState(() => _selectedStatus = null);
                        _loadMembers();
                      },
                    ),
                ],
              ),
            ),
          // Members list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _members.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty || _selectedRole != null || _selectedStatus != null
                                  ? "No members found"
                                  : "No members yet",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadMembers,
                        child: ListView.builder(
                          itemCount: _members.length,
                          itemBuilder: (context, index) => _buildMemberCard(_members[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
