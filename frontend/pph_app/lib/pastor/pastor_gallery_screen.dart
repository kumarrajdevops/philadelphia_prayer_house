import 'package:flutter/material.dart';

class PastorGalleryScreen extends StatelessWidget {
  const PastorGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gallery"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            tooltip: "Upload Photo",
            onPressed: () {
              // TODO: Upload photo
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Upload Photo - Coming soon")),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "Gallery Management",
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
                  const SnackBar(content: Text("Upload Media - Coming soon")),
                );
              },
              icon: const Icon(Icons.cloud_upload),
              label: const Text("Upload Media"),
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

