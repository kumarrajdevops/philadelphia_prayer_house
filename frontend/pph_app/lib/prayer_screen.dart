import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  List prayers = [];

  Future<void> loadPrayers() async {
    try {
      final res = await http.get(
        Uri.parse("http://10.0.2.2:8000/prayers"),
      );

      if (res.statusCode == 200) {
        setState(() {
          prayers = json.decode(res.body);
        });
      }
    } catch (e) {
      debugPrint("Error loading prayers: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(loadPrayers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Prayer Schedule"),
      ),
      body: prayers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: prayers.length,
        itemBuilder: (context, index) {
          final p = prayers[index];
          return Card(
            margin: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.self_improvement),
              title: Text(p['title']),
              subtitle: Text(
                "${p['prayer_date']}  |  ${p['start_time']} - ${p['end_time']}",
              ),
            ),
          );
        },
      ),
    );
  }
}
