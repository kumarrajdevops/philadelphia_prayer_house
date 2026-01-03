import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'prayer_screen.dart';

void main() {
  runApp(const PPHApp());
}

class PPHApp extends StatelessWidget {
  const PPHApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Philadelphia Prayer House',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List users = [];

  Future<void> loadUsers() async {
    try {
      final res = await http.get(
        Uri.parse("http://10.0.2.2:8000/users"),
      );

      if (res.statusCode == 200) {
        setState(() {
          users = json.decode(res.body);
        });
      }
    } catch (e) {
      debugPrint("Error loading users: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(loadUsers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Philadelphia Prayer House"),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule),
            tooltip: "Prayer Schedule",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrayerScreen(),
                ),
              );
            },
          )
        ],
      ),
      body: users.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: users
            .map(
              (u) => ListTile(
            leading: const Icon(Icons.person),
            title: Text(u['name']),
            subtitle: Text(u['role']),
          ),
        )
            .toList(),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: "Add User",
        onPressed: () async {
          await http.post(
            Uri.parse("http://10.0.2.2:8000/users"),
            headers: {"Content-Type": "application/json"},
            body: json.encode(
              {"name": "Member ${users.length + 1}"},
            ),
          );
          loadUsers();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
