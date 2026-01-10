import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import '../auth/auth_service.dart';
import '../utils/api_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? username;
  String? role;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadUserInfo();
  }

  Future<void> loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString("username");
      role = prefs.getString("role");
      loading = false;
    });
  }

  Future<void> logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isPastor = role == "pastor" || role == "admin";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Philadelphia Prayer House"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.person, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome, ${username ?? 'User'}!",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Role: ${role ?? 'member'}",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isPastor) ...[
              const Text(
                "Pastor Actions",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.add_circle, color: Colors.blue),
                  title: const Text("Create Prayer"),
                  subtitle: const Text("Schedule a new prayer session"),
                  onTap: () {
                    // TODO: Navigate to create prayer screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Create Prayer - Coming soon"),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
            const Text(
              "Quick Actions",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.schedule, color: Colors.blue),
                    title: const Text("Prayer Schedule"),
                    subtitle: const Text("View upcoming prayers"),
                    onTap: () {
                      // TODO: Navigate to prayer schedule
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Prayer Schedule - Coming soon"),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.live_tv, color: Colors.red),
                    title: const Text("Live Prayer"),
                    subtitle: const Text("Join live prayer session"),
                    onTap: () {
                      // TODO: Navigate to live prayer
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Live Prayer - Coming soon"),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.book, color: Colors.blue),
                    title: const Text("Bible"),
                    subtitle: const Text("Read Bible verses"),
                    onTap: () {
                      // TODO: Navigate to Bible
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Bible - Coming soon"),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

