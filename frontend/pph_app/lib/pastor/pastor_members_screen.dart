import 'package:flutter/material.dart';

class PastorMembersScreen extends StatelessWidget {
  const PastorMembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Members"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: "Search Members",
            onPressed: () {
              // TODO: Show search
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Search Members - Coming soon")),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: "Filter",
            onPressed: () {
              // TODO: Show filter
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Filter Members - Coming soon")),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "Members Management",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Coming soon",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Manage Members - Coming soon")),
                );
              },
              icon: const Icon(Icons.person_add),
              label: const Text("Approve Members"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

