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
    required String prayerType, // "online" or "offline"
    String? location, // Required for offline prayers
    String? joinInfo, // Required for online prayers (WhatsApp link/instructions)
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
        "prayer_type": prayerType,
        "location": location,
        "join_info": joinInfo,
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

  /// Update a prayer by ID
  /// Returns the updated prayer data on success, null on failure
  static Future<Map<String, dynamic>?> updatePrayer({
    required int prayerId,
    required String title,
    required DateTime prayerDate,
    required DateTime startTime,
    required DateTime endTime,
    required String prayerType, // "online" or "offline"
    String? location, // Required for offline prayers
    String? joinInfo, // Required for online prayers (WhatsApp link/instructions)
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
        "prayer_type": prayerType,
        "location": location,
        "join_info": joinInfo,
      });

      final res = await http.put(
        ApiClient.uri("/prayers/$prayerId"),
        headers: headers,
        body: body,
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print("Update prayer failed: ${res.statusCode} - ${res.body}");
        try {
          final errorData = jsonDecode(res.body);
          throw Exception(errorData["detail"] ?? "Failed to update prayer");
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception("Failed to update prayer");
        }
      }
    } catch (e) {
      print("Update prayer error: $e");
      rethrow;
    }
  }

  /// Delete a prayer
  /// Returns true on success, false on failure
  /// Throws exception if prayer has already started
  static Future<bool> deletePrayer(int prayerId) async {
    try {
      final headers = await ApiClient.authHeaders();
      
      final res = await http.delete(
        ApiClient.uri("/prayers/$prayerId"),
        headers: headers,
      );

      if (res.statusCode == 204) {
        return true;
      } else {
        print("Delete prayer failed: ${res.statusCode} - ${res.body}");
        try {
          final errorData = jsonDecode(res.body);
          throw Exception(errorData["detail"] ?? "Failed to delete prayer");
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception("Failed to delete prayer");
        }
      }
    } catch (e) {
      print("Delete prayer error: $e");
      rethrow;
    }
  }
}

