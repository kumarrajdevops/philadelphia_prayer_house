import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_client.dart';

class PrayerService {
  /// Create a new prayer
  /// Returns the created prayer data on success, null on failure
  static Future<Map<String, dynamic>?> createPrayer({
    required String title,
    required DateTime prayerDate,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      
      // Format date as YYYY-MM-DD
      final dateStr = "${prayerDate.year}-${prayerDate.month.toString().padLeft(2, '0')}-${prayerDate.day.toString().padLeft(2, '0')}";
      
      // Format time as HH:MM:SS
      final startTimeStr = "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00";
      final endTimeStr = "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00";
      
      final body = jsonEncode({
        "title": title,
        "prayer_date": dateStr,
        "start_time": startTimeStr,
        "end_time": endTimeStr,
      });

      final res = await http.post(
        ApiClient.uri("/prayers"),
        headers: headers,
        body: body,
      );

      if (res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print("Create prayer failed: ${res.statusCode} - ${res.body}");
        return null;
      }
    } catch (e) {
      print("Create prayer error: $e");
      rethrow;
    }
  }

  /// Get all prayers
  static Future<List<Map<String, dynamic>>> getAllPrayers() async {
    try {
      final res = await http.get(
        ApiClient.uri("/prayers"),
        headers: {"Content-Type": "application/json"},
      );

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print("Get prayers failed: ${res.statusCode} - ${res.body}");
        return [];
      }
    } catch (e) {
      print("Get prayers error: $e");
      return [];
    }
  }
}

